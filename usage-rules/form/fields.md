# Form → `fields`

Every input: its type, validation, access, relation loading and nested shape.

```elixir
fields do
  field_order [:title, :slug, :status]          # unlisted fields go last

  field :title do                                # type omitted ⇒ inferred from the Ash attribute
    required true
    ui do
      label fn -> dgettext("mishka_gervaz", "Title") end
      placeholder "Post title"
      span 2
    end
  end

  field :status do
    options [{dgettext("mishka_gervaz", "Draft"), :draft}, {"Published", :published}]
  end
end
```

## Types

`:text` · `:password` · `:textarea` · `:number` · `:checkbox` · `:toggle` · `:date` · `:datetime` ·
`:range` · `:select` · `:multi_select` · `:combobox` · `:relation` · `:json` · `:nested` ·
`:array_of_maps` · `:string_list` · `:file` · `:upload` · `:hidden` · or a module implementing
`MishkaGervaz.Form.Behaviours.FieldType`
([../customization/types.md](../customization/types.md)).

Omit `type` and it is inferred from the Ash attribute:

| Ash type | Field type |
|---|---|
| `Ash.Type.String` | `:text` |
| `Ash.Type.Integer` / `Float` / `Decimal` | `:number` |
| `Ash.Type.Boolean` | `:checkbox` |
| `Ash.Type.Date` | `:date` |
| `Ash.Type.DateTime` / `UtcDatetime` / `UtcDatetimeUsec` | `:datetime` |
| `Ash.Type.Map` | `:json` |
| anything else | `:text` |

An attribute with `constraints one_of:` still needs its `options` written out.

## Options

| Option | Type | Default | Note |
|---|---|---|---|
| `source` | atom | field name | attribute when it differs from the field name |
| `required` | bool | `false` | |
| `visible` / `restricted` / `readonly` | bool \| `fn state ->` | `true` / `false` / `false` | arity **1** |
| `show_on` | `:create` \| `:update` | — | show only in that mode |
| `default` | any | — | |
| `depends_on` | atom | — | cascading select; must be a field in this form |
| `virtual` | bool | `false` | not a resource attribute |
| `resource` | Ash resource | — | **required** for virtual `:relation` / `:select` |
| `derive_value` | `fn record -> value` | — | how edit mode reads a virtual field off the record |
| `options` | list \| `fn -> list` \| `fn state -> list` | — | function runs at load; `fn state` only on a resource-less `:relation` |
| `options_source` | `{resource, action, display_field}` | — | ⚠ not wired — use `options` or `load` |
| `display_field` | atom \| `fn r ->` \| `fn r, state ->` | — | relation label |
| `search_field` | atom | — | autocomplete field |
| `value_field` | atom | — | store this attribute instead of `:id` |
| `mode` | `:static` \| `:load_more` \| `:search` \| `:search_multi` | `:static` | |
| `page_size` | pos int | `20` | |
| `load_action` | atom \| `{master, tenant}` | — | its pagination must be `required?: false` |
| `load` | `fn query, state -> query` | — | scopes the option list |
| `apply` | `fn value, changeset, state -> changeset` | — | ⚠ see below |
| `format` | `fn value ->` \| `fn state, record, value ->` | — | ⚠ see below |
| `render` | `fn record ->` \| `fn record, state ->` | — | ⚠ see below |
| `position` | int \| `:first` \| `:last` \| `{:before, f}` \| `{:after, f}` | — | |
| `include_nil` | bool \| string \| `fn -> string` | `false` | adds a nil option; the string is its label |
| `min` / `max` | int | — | `:number` / `:range` |
| `min_chars` | int | — | before search fires |
| `auto_fields` | bool | `false` | on `:nested`, auto-detect the sub-fields you did not declare |
| `nested_fields` | list | `[]` | filled by the `nested_field` entities |
| `array_fields` | list | `[]` | ⚠ not wired |
| `add_label` / `remove_label` | string \| `fn -> string` | — | repeater buttons |

### ⚠ `apply`, `format`, `render`, `options_source`, `array_fields` are declared but not wired

All five are accepted by the schema and land in `Info.Form.fields/1`, but **no built-in form
template or handler reads them** — on the form side only `render` on `header` / `footer` /
`notice` is consumed. Verified against `lib/mishka_gervaz/form/`.

So today they are extension points for a custom template
([../customization/form-templates.md](../customization/form-templates.md)), not working options.
To change a value on the way in, use `hooks do before_save / transform_params end`
([hooks.md](hooks.md)); to change how an input renders, use a
[custom field type](../customization/types.md) or the
[UI adapter](../customization/ui-adapters.md).

On the **table** side the same names *are* wired: a column's `format` and `render` both run, and a
filter's `apply` is `fn query, value, state -> query` — a different shape from the form field's
`fn value, changeset, state -> changeset`.

## `ui do … end`

`label` · `placeholder` · `description` · `icon` · `class` · `wrapper_class` · `debounce` ·
`span` · `rows` · `step` · `autocomplete` · `add_label` · `remove_label` · `disabled_prompt` ·
`extra`.

## Relation fields — the pattern that recurs

```elixir
field :tag_ids, :relation do
  virtual true
  resource MyApp.Blog.Tag
  display_field :name
  search_field :name
  mode :search_multi
  depends_on :site_id

  load fn query, state ->
    site_id =
      if state.master_user?,
        do: Map.get(state.field_values, :site_id),
        else: Map.get(state.current_user, :site_id)

    Ash.Query.filter_input(query, %{site_id: site_id})
  end

  derive_value fn record ->
    (Map.get(record, :master_tags) || Map.get(record, :tags) || [])
    |> Enum.map(&to_string(&1.id))
  end
end
```

`load` scopes the **options**; `derive_value` is how edit mode reads the current value off the
loaded record — a virtual field has no attribute to read. A virtual many-relationship needs both.

`value_field` stores a non-primary-key attribute from the chosen record.
`include_nil fn -> dgettext(…) end` adds a labelled "none" option — useful for "auto-generate".

A choice that follows another field but is **not rows of a resource** — the languages of the picked
site — is a `:relation` with no `resource` whose `options` is `fn state -> list end`. It is read again
on every load, a `depends_on` change included, and it loads at init even while the parent is empty or
restricted, so the function decides what that means (a site admin's own site, say):

```elixir
field :language, :relation do
  depends_on :site_id
  mode :search

  options fn state ->
    site_id =
      if state.master_user?,
        do: Map.get(state.field_values, :site_id),
        else: Map.get(state.current_user, :site_id)

    MyApp.Languages.options_for(site_id)   # [{"EN", "en"}, {"FA", "fa"}]
  end
end
```

A picked `include_nil` parent arrives as `"__nil__"`, not `nil`.

## Which knob changes a value, and where — compared

Seven options touch "the value". They act at different points, and picking the wrong one is the
most common source of a field that looks right and saves wrong.

| Option | Acts | Receives | Returns | Wired? |
|---|---|---|---|---|
| `default` | before **create** renders | — | any | ✔ |
| `derive_value` | when **edit** loads | `record` | any | ✔ — the only way a `virtual` field reads its current value |
| `options` | when the input renders | — | `[{label, value}]` | ✔ |
| `load` | when relation options load | `query, state` | `query` | ✔ — scopes the choice list |
| `options_source` | — | — | — | ✖ compiled but never read |
| `format` | display | `value`, or `state, record, value` | any | ✖ see below |
| `apply` | save | `value, changeset, state` | `changeset` | ✖ see below |
| `render` | instead of the input | `record`, or `record, state` | HEEx | ✖ see below |

Read the wired ones as a timeline: `default` / `derive_value` fill the field → `options` / `load`
populate the choices → the field type and the UI adapter draw it → the Ash action writes it.

To change a value on the way **in**, use `hooks do before_save / transform_params end`. To change
how an input **draws**, use a custom field type or the UI adapter.

Three related pairs worth keeping straight:

- **`visible` vs `show_on` vs `restricted`** — `visible` is any predicate, `show_on` is
  "this mode only", `restricted` is "masters only". Use the narrowest that says what you mean.
- **`options` vs `load`** — `options` is a list; `load` scopes an Ash query. A `:relation` field
  uses `load`; a `:select` uses `options`.
- **`load` vs `apply`** — `load` narrows what the reader may pick; `apply` decides what happens
  when they pick it. On a table filter the same two names mean different things
  ([../table/filters.md](../table/filters.md)) — and `apply`'s argument order differs.

## Nested fields

For an embedded resource or a constrained `{:array, :map}` attribute:

```elixir
field :seo_tags, :nested do
  ui do
    label fn -> dgettext("mishka_gervaz", "SEO Tags") end
    add_label fn -> dgettext("mishka_gervaz", "+ Add SEO Tag") end
    remove_label fn -> dgettext("mishka_gervaz", "Remove") end
  end

  nested_field :tag do ui do placeholder "meta, link, script" end end
  nested_field :attrs, :json do … end
  nested_field :content, :textarea do ui do rows 3 end end
end
```

`nested_field` accepts a **narrower** type set: `:text` `:textarea` `:number` `:checkbox` `:date`
`:datetime` `:select` `:hidden` `:toggle` `:range` `:json` — or `nil` for auto-detection.
Options: `name` · `type` · `required` (nil ⇒ inferred from `allow_nil?`) · `visible` · `readonly` ·
`default` · `options` · `position`; `ui`: `label` · `placeholder` · `description` · `class` ·
`rows` · `span` · `extra`.

A `nested_field` outside a `:nested` field fails the build.

## `auto_fields`

```elixir
fields do
  auto_fields do
    except [:id, :archived_at]            # or: only [:name, :status]
    position :end                          # :start | :end
    defaults required: false, visible: true, readonly: false
    ui_defaults do
      boolean_widget :checkbox             # :checkbox | :toggle | :select
      textarea_threshold 255               # a string longer than this becomes a textarea
      number_step 1
      select_prompt "Select..."
      datetime_format :medium
    end
    override :age, type: :range, required: true
    override :bio do ui do label "Biography"; rows 8 end end
  end
end
```

`override`'s `type` accepts the built-ins **except** `:upload`, `:combobox` and `:password` —
declare those as explicit `field`s.

## Rules the compiler enforces

- Every non-`virtual` field name maps to an attribute, relationship, calculation or aggregate.
- `depends_on` names a field declared in the same form.
- A virtual `:relation` / `:select` declares a `resource`.
- `nested_field` appears only inside a `:nested` field.

## TODO
- [ ] Non-virtual field names exist on the resource
- [ ] `virtual true` on `:relation` / `:select` paired with `resource`
- [ ] Virtual many-relations have both `load` and `derive_value`
- [ ] `depends_on` names a field in this form, and `load` reads it from `state.field_values`
- [ ] `apply` written as `fn value, changeset, state ->`
- [ ] `nested_field` only inside `:nested`, and only with the narrower type set
- [ ] `show_on` used where a field belongs to one mode only
- [ ] `restricted true` on every master-only field
- [ ] Labels via `fn -> dgettext("mishka_gervaz", "…") end`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.fields`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields) · [`mishka_gervaz.form.fields.field`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-field) · [`mishka_gervaz.form.fields.field.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-field-ui) · [`mishka_gervaz.form.fields.field.preload`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-field-preload) · [`mishka_gervaz.form.fields.field.nested_field`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-field-nested_field) · [`mishka_gervaz.form.fields.field.nested_field.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-field-nested_field-ui) · [`mishka_gervaz.form.fields.auto_fields`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-auto_fields) · [`mishka_gervaz.form.fields.auto_fields.defaults`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-auto_fields-defaults) · [`mishka_gervaz.form.fields.auto_fields.ui_defaults`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-auto_fields-ui_defaults) · [`mishka_gervaz.form.fields.auto_fields.override`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-fields-auto_fields-override)

**Schema:** `MishkaGervaz.Form.Entities.Field`, `.Field.Ui`, `.Field.Preload`, `.NestedField`,
`.AutoFields` · **Verifier:** `Form.Verifiers.ValidateFields` ·
**Types:** `MishkaGervaz.Form.Types.Field`
