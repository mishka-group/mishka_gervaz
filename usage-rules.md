# Rules for Working with MishkaGervaz

MishkaGervaz turns an Ash resource into a working admin surface — a list view (`table`) and a
create/edit form (`form`) — declared entirely in a Spark DSL and rendered by two LiveComponents.
You write DSL; the library builds the state, runs the Ash queries, wires every `phx-` event, and
renders through a swappable UI adapter.

**Every option named in these rules is read from the DSL schema in `lib/`. An option not listed
here does not exist — do not invent one.** When you need a detail these rules do not cover, read
the schema module named in the section (e.g. `MishkaGervaz.Table.Entities.Column`), never guess.

## Sub-rules — read the one for the job

Each file covers one DSL section. Open the index, then the section.

| You are doing this | Read |
|---|---|
| Anything in `table do … end` | [usage-rules/table.md](usage-rules/table.md) → per-section files under `usage-rules/table/` |
| Anything in `form do … end` | [usage-rules/form.md](usage-rules/form.md) → per-section files under `usage-rules/form/` |
| Rendering a component in a LiveView — assigns, messages, URL sync, PubSub, modals | [usage-rules/mounting.md](usage-rules/mounting.md) |
| Going beyond the DSL | [usage-rules/customization.md](usage-rules/customization.md) → [ui-adapters](usage-rules/customization/ui-adapters.md) · [table-templates](usage-rules/customization/table-templates.md) · [form-templates](usage-rules/customization/form-templates.md) · [types](usage-rules/customization/types.md) · [overrides](usage-rules/customization/overrides.md) |
| A compile error, or a surface that renders wrong | [usage-rules/troubleshooting.md](usage-rules/troubleshooting.md) |

> Some DSL options compile but are not read by any built-in template or handler. Before relying on
> one, check the **"Declared but not wired"** table in
> [troubleshooting.md](usage-rules/troubleshooting.md) — it is the single index of them.

Everything below is needed by **every** job. Read it once, then go to the sub-rule.

---

## 1. Install and wire up

```elixir
# mix.exs
{:mishka_gervaz, "~> 0.0.1-alpha.5"}
```

Runtime deps it brings: `ash ~> 3.29`, `ash_phoenix ~> 2.3`, `spark ~> 2.7`, `splode ~> 0.3.1`,
`gettext ~> 1.0`, `jason ~> 1.4`, `html_sanitize_ex ~> 1.5`. `phoenix_live_view ~> 1.2` is an
**optional** dep — your Phoenix app supplies it.

```elixir
# .formatter.exs — without this the parenless DSL is reformatted into calls with parens
[
  import_deps: [:ash, :spark, :phoenix, :mishka_gervaz],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{heex,ex,exs}"]
]
```

```elixir
# config/config.exs — optional. Default backend is MishkaGervaz.Gettext.
config :mishka_gervaz, :gettext_backend, MyApp.Gettext
```

All library strings live in the **`mishka_gervaz` gettext domain**
(`priv/gettext/<locale>/LC_MESSAGES/mishka_gervaz.po`), except the messages a form field type
refuses a value with, which are in the **`errors` domain** beside Ash's own. With `:gettext_backend`
set to your backend, give your translators both of the library's templates,
`priv/gettext/mishka_gervaz.pot` and `priv/gettext/errors.pot`, merged into yours. Label options
accept `fn -> dgettext("mishka_gervaz", "Title") end` — prefer that over a bare string wherever a
label reaches a human.

A table's or form's loads run in the Gettext locale of the page. For your own work in another
process whose result holds words, use `MishkaGervaz.Messages.start_async/4`,
`MishkaGervaz.Messages.assign_async/4` or `MishkaGervaz.Messages.in_caller_locale/1`.

Then add the extension in two places:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [MishkaGervaz.Domain]   # defaults for every resource below
end

defmodule MyApp.Blog.Post do
  use Ash.Resource, domain: MyApp.Blog, extensions: [MishkaGervaz.Resource]
end
```

**TODO — wiring**
- [ ] `{:mishka_gervaz, "~> 0.0.1-alpha.5"}` in `mix.exs`
- [ ] `:mishka_gervaz` added to `import_deps` **and** `Spark.Formatter` in `plugins`
- [ ] `MishkaGervaz.Domain` on the Ash domain, `MishkaGervaz.Resource` on each resource
- [ ] Domain declares `actions`, `pagination`, `realtime.pubsub`, `archive`, `form.actions`, `form.submit` once (see §3)
- [ ] `:gettext_backend` configured if you want your app's translations

---

## 2. The shape of the DSL

One `mishka_gervaz do … end` block per module, with two independent sibling sections. A resource
may declare either, both, or neither.

```
mishka_gervaz do
  table do   # 14 sections + 6 top-level entities → usage-rules/table.md
  end

  form do    #  9 sections + 3 top-level entities → usage-rules/form.md
  end
end
```

Compile order is fixed: `MergeDefaults` (domain inheritance, derived identity) →
`ResolveColumns` / `ResolveFields` (auto-discovery, type inference, positions, detected preloads)
→ `BuildRuntimeConfig` (one persisted map) → **verifiers** (see troubleshooting.md). Runtime reads
only the persisted map, through `MishkaGervaz.Resource.Info.Table` / `.Form`.

At runtime the LiveComponent is five layers, all replaceable:
`State` (config + dynamic state) → `DataLoader` (Ash queries, relation options) →
`Events` (every `phx-` event) → `Renderer` → **Template** (*where* things go) +
**UIAdapter** (*how* they look).

---

## 3. Domain defaults are the point — declare them once

The domain extension is not decoration. Put anything shared there; a resource overrides
**per key**, never per block.

```elixir
mishka_gervaz do
  table do
    actor_key :current_user
    ui_adapter MishkaGervaz.UIAdapters.Tailwind

    pagination do
      type :load_more
      page_size 20
      page_size_options [20, 50, 100, 150]
    end

    realtime do
      pubsub MyApp.PubSub
    end

    actions do
      read    {:master_read, :read}
      get     {:master_get, :read}
      destroy {:master_destroy, :destroy}
    end

    archive do
      read_action    {:master_archived, :archived}
      get_action     {:master_get_archived, :get_archived}
      restore_action {:master_unarchive, :unarchive}
      destroy_action {:master_permanent_destroy, :permanent_destroy}
    end
  end

  form do
    actions do
      create {:master_create, :create}
      update {:master_update, :update}
      read   {:master_get, :read}
    end

    submit do
      create label: fn -> dgettext("mishka_gervaz", "Create") end
      update label: fn -> dgettext("mishka_gervaz", "Save Changes") end
      cancel label: fn -> dgettext("mishka_gervaz", "Cancel") end
      position :bottom
    end
  end

  navigation do
    menu_group :content do
      label "Content"
      icon "hero-document"
      position 1
      resources [MyApp.Blog.Post, MyApp.Blog.Tag]
      visible fn user -> user.role == :admin end
    end
  end
end
```

Keys a resource inherits (everything else is resource-only):

| Table | Form |
|---|---|
| `ui_adapter`, `ui_adapter_opts` | `ui_adapter`, `ui_adapter_opts` |
| `actor_key`, `master_check` | `actor_key`, `master_check` |
| `actions.read / .get / .destroy` | `actions.create / .update / .read` |
| `pagination.*` (all keys) | `layout.navigation`, `layout.persistence`, `layout.columns`, `layout.responsive` |
| `realtime.enabled`, `realtime.pubsub` | `template`, `features`, `theme.*` |
| `theme.header_class / .row_class / .border_class` | `submit` (merged **per button**, see form.md) |
| `archive.*`, `url_sync.*`, `refresh.*` | |

`realtime.enabled false` on a resource beats `true` on the domain — `false` is an answer, not an
absence. Read the merged result with `MishkaGervaz.Domain.Info.Table.config/1` /
`MishkaGervaz.Domain.Info.Form.config/1`.

**TODO — domain**
- [ ] `actions` declared on the domain (a table without `read` will not compile)
- [ ] `archive` block if any resource uses `AshArchival.Resource`
- [ ] `realtime.pubsub` set on the domain, `realtime.prefix` set per resource
- [ ] `navigation.menu_group` for the admin sidebar, if you have one

---

## 4. Master / tenant — the concept every other rule assumes

Gervaz assumes two kinds of user: a **master** (cross-tenant operator) and a **tenant** user
(scoped to one site/org). One DSL drives both.

- Every action option takes an atom (same action for both) or a `{master_action, tenant_action}`
  tuple. The tuple is picked at runtime by `master_check`.
- `master_check` is `fn user -> boolean end`, set on the domain or the resource. The **form** side
  falls back to `MishkaGervaz.Helpers.master_user?/1` when neither declares one; the **table** side
  leaves it `nil` — declare it.
- `restricted` on an entity means *master-only*.
- Preloads are three-tier — `always` / `master` / `tenant` — so the two roles can expose different
  relationships under the same alias:

  ```elixir
  preload do
    always [:site]
    master master_media_category: :media_category
    tenant [:media_category]
  end
  ```

  `preload_aliases` on the state maps the alias back, so a column/field reads
  `record.media_category` for both roles.
- For a **non-multitenant** resource, only the second (tenant) element of a tuple is ever used.

**TODO — access**
- [ ] `master_check` set on the domain (table side has no fallback)
- [ ] Every cross-tenant action given as a `{master, tenant}` tuple
- [ ] `restricted true` on every field/filter/column that only a master may see
- [ ] Preloads split `always` / `master` / `tenant` when the relationship names differ

---

## 5. The three slots — `source`, `ui`, `render`

Every column and field is described in exactly three slots. Putting a value in the wrong one is
the most common mistake in this DSL.

| Slot | Answers | Examples |
|---|---|---|
| **entity body** (`source`, `sortable`, `required`, `mode`, `visible`, `restricted`, `load`, `apply`, `format`) | *what the data is and how it behaves* | `sortable true`, `mode :search_multi`, `required true` |
| **`ui do … end`** | *how it is presented* | `label`, `placeholder`, `icon`, `class`, `width`, `type`, `span`, `rows`, `extra` |
| **`render fn … end`** | *replace the output entirely* with HEEx | a custom cell / input |

`ui.extra` is the escape hatch map for options a template or column type invented — it is never
validated, so read the type module before filling it.

`label` is special: on a **column** it exists both in the entity body (shorthand) and in `ui`; on
everything else it lives only in `ui`.

**TODO — every column/field you write**
- [ ] Behaviour options in the body, presentation in `ui`, markup only in `render`
- [ ] Label given as `fn -> dgettext("mishka_gervaz", "…") end`
- [ ] `ui.extra` filled only after reading the type module that consumes it

---

## 6. Predicates — the arities differ, and that is the trap

`visible` / `restricted` / `readonly` / `disabled` accept a boolean or a function. **The arity
depends on the entity.** Getting it wrong is a `BadArityError` at render time, not a compile error.

| Entity | `visible` signature |
|---|---|
| table `column` | `fn state -> boolean end` |
| table `filter`, `filter_group` | `fn state -> boolean end` |
| table `row_actions.action` | `:active` \| `:archived` \| `true` \| `false` \| **`fn record, state -> boolean end`** |
| table `bulk_actions.action` | `:active` \| `:archived` \| **`fn state -> boolean end`** (default `:active`) |
| table/form `header`, `footer`, `notice` | `fn state -> boolean end` |
| form `field`, `group`, `step`, `submit` button | `fn state -> boolean end` |
| domain `menu_group` | `fn user -> boolean end` |
| table `realtime.visible` | `fn record, user -> boolean end` |

The `state` is the live state struct. The fields you may read:

```
# table state           # form state
state.current_user      state.current_user
state.master_user?      state.master_user?
state.template          state.mode              # :create | :update
state.archive_status    state.current_step
state.filter_values     state.field_values
state.path_params       state.form              # AshPhoenix.Form
state.selected_ids      state.errors / .form_errors
state.total_count       state.dirty?
state.loading           state.relation_options
state.records_result    state.existing_files
state.loaded_records    state.defaults
state.static.<config>   state.static.<config>
```

`state.template` is the **template module** — compare with `state.template.name() == :table` or
against a module attribute holding the module.

**TODO — every predicate**
- [ ] Arity checked against the table above
- [ ] Only fields listed above read off `state`
- [ ] `:active` / `:archived` used instead of a function where it says what you mean

---

## 7. Non-negotiables

1. **`identity` is required.** Table: `name` **and** `route`, enforced as soon as you declare any
   column/filter/row action/bulk action. Form: `name` only (derived as `<resource>_form` when
   omitted — declare it anyway, it is the LiveComponent id).
2. **`source.actions.read` is required** for a table, on the resource or the domain. `get` becomes
   required once rows are interactive; `destroy` once a `:destroy` action exists. A form with any
   field requires `create`, `update` **and** `read`.
3. **A static column must say what it needs.** `static true` means "no DB source" — pair it with
   `requires [...]`, and with `sort_field [...]` if it is also `sortable`.
4. **A preloaded relationship's read action must not require pagination.** Use
   `pagination offset?: true, required?: false` on it, or the load raises `LimitRequired`. This is
   caught at compile time for form preloads.
5. **`archive` needs `AshArchival.Resource`**, and a resource that has `AshArchival.Resource` needs
   an `archive` block on itself or its domain.
6. **`realtime` needs a `prefix`** whenever it is enabled.
7. **Groups partition fields.** A field may appear in at most one group; a group may appear in at
   most one step.
8. **Never `String.to_atom/1` on anything reaching this DSL**, and never interpolate user input into
   `path`/`confirm` without escaping — the library sanitizes form input, not your `render`.

---

## 8. Introspection

Read compiled config at runtime rather than re-deriving it:

```elixir
alias MishkaGervaz.Resource.Info.Table, as: TableInfo
alias MishkaGervaz.Resource.Info.Form,  as: FormInfo

TableInfo.config(MyApp.Post)          # whole merged map
TableInfo.columns(MyApp.Post)
TableInfo.filters(MyApp.Post)
TableInfo.row_actions(MyApp.Post)
TableInfo.pagination_enabled?(MyApp.Post)
TableInfo.archive_enabled?(MyApp.Post)
TableInfo.action_for(MyApp.Post, :read, master? = true)
TableInfo.all_preloads(MyApp.Post, master?)

FormInfo.component_id(MyApp.Post)     # the id to mount the form LiveComponent with
FormInfo.fields(MyApp.Post)
FormInfo.steps(MyApp.Post)
FormInfo.submit(MyApp.Post)
```

`MishkaGervaz.ResourceInfo` and `MishkaGervaz.DomainInfo` are flat delegates over the same
functions with a `table_` / `form_` prefix (`ResourceInfo.table_columns/1`,
`DomainInfo.form_submit/1`). Same names, same arities, no shortcuts.

**TODO — before writing a helper**
- [ ] Checked `Resource.Info.Table` / `Resource.Info.Form` for an accessor that already answers it
- [ ] Used `MishkaGervaz.Helpers` (`humanize/1`, `resolve_label/1..3`, `resolve_options/1`,
      `normalize_options/1`, `format_filesize/1`, `dynamic_component/1`) rather than re-implementing

---

## 9. Errors

Failures are `Splode` errors under `MishkaGervaz.Errors` — classes `:data`
(`Errors.Data.LoadFailed`) and `:action` (`Errors.Action.Failed`), with `Errors.Unknown` as the
catch-all. `MishkaGervaz.Errors.format_flash_message/1` renders any of them (plus Ash errors) as a
flash string.

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`
