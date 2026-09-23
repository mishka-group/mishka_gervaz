# Table → `filters`

The filter inputs, and how each value narrows the query.

```elixir
filters do
  filter :search, :text, fields: [:title, :slug, :excerpt]

  filter :status, :select do
    options [{"Published", :published}, {"Draft", :draft}]
    ui do prompt "All statuses"; label fn -> dgettext("mishka_gervaz", "Status") end end
  end

  filter :site_id, :relation do
    mode :search_multi
    display_field :name
    search_field :name
    min_chars 1
    page_size 15
    restricted true
  end

  filter :created_at, :date_range, source: :inserted_at
end
```

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.filters`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filters) · [`mishka_gervaz.table.filters.filter`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filters-filter) · [`mishka_gervaz.table.filters.filter.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filters-filter-ui) · [`mishka_gervaz.table.filters.filter.preload`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filters-filter-preload)

**Types:** `:text` (default) · `:select` · `:boolean` · `:number` · `:date` · `:date_range` ·
`:relation` · or a module implementing `MishkaGervaz.Table.Behaviours.FilterType`
([../customization/types.md](../customization/types.md)).

`:text` matches part of a value **without case**, and a `%` or `_` in the term is that character —
the term is an `Ash.CiString`, an escaped `ILIKE` on AshPostgres. A relation filter's search matches
the same way. Anything else — a word boundary, a prefix only — is a custom `apply`.

## Options

| Option | Type | Default | Note |
|---|---|---|---|
| `source` | atom | name | DB field when it differs from the filter name |
| `fields` | `[atom]` | — | multi-field search — `:text` only |
| `depends_on` | atom | — | cascade: disabled until the parent has a value |
| `visible` / `restricted` | bool \| `fn state ->` | `true` / `false` | arity **1** |
| `options` | list \| `fn -> list` | — | the function runs **once at mount** |
| `default` | any | — | pre-selected on first load |
| `presets` | `[{label, map}]` | — | ⚠ compiled but not read by any built-in filter type |
| `display_field` | atom \| `fn r ->` \| `fn r, state ->` | — | relation label |
| `search_field` | atom | — | **required** when `display_field` is a function |
| `include_nil` | bool \| string | `false` | |
| `min` / `max` | int | — | `:number` |
| `min_chars` | int | `2` | before search fires |
| `virtual` | bool | `false` | documents intent; the behaviour comes from `resource` + `apply` |
| `resource` | Ash resource | — | where a virtual filter's options come from |
| `load_action` | atom | `:read` | |
| `load` | `fn query, state -> query` | — | scopes the **option list** |
| `apply` | `fn query, value, state -> query` | — | how the value filters the **main query** |
| `mode` | `:static` \| `:load_more` \| `:search` \| `:search_multi` | `:static` | relation loading |
| `page_size` | pos int | `20` | paginated modes |

`ui`: `label` · `placeholder` · `prompt` (`"Select..."`) · `disabled_prompt` · `icon` ·
`debounce` (`300`) · `extra`.

`preload do always/master/tenant end` inside a relation filter loads what `display_field` reads.

## Cascading filters

`depends_on` disables the child until the parent has a value; the child's `load` reads that value
off `state.filter_values`:

```elixir
filter :media_category_id, :relation do
  display_field &if &2.master_user?, do: "#{&1.name} - #{&1.site.name}", else: &1.name
  search_field :name
  mode :search
  depends_on :site_id

  preload do always [:site] end

  load fn query, state ->
    site_id =
      if state.master_user?,
        do: Map.get(state.filter_values, :site_id),
        else: Map.get(state.current_user || %{}, :site_id)

    if site_id, do: Ash.Query.filter(query, site_id == ^site_id), else: query
  end

  ui do disabled_prompt fn -> dgettext("mishka_gervaz", "Select Site first") end end
end
```

## Virtual filters

A filter with no DB column of its own — it names its target `resource` and says how the chosen
value narrows the main query. The `virtual true` flag itself is advisory: what makes it work is
`resource` (where options come from) and `apply` (what picking one does). Without `apply` the
query builder falls back to filtering on `source`, which for a virtual filter does not exist.

```elixir
filter :collection_id, :relation do
  virtual true
  resource MyApp.Blog.Collection
  mode :search
  display_field :name
  search_field :name

  apply fn query, value, context ->
    rel = if context.master_user?, do: "master_collections", else: "tenant_collections"
    Ash.Query.filter_input(query, %{rel => %{"id" => %{"in" => List.wrap(value)}}})
  end
end
```

## Which knob does what — compared

| Option | Acts on | Receives | Returns | Reach for it when |
|---|---|---|---|---|
| `source` | the **main query** | — | — | the DB field is named differently from the filter |
| `fields` | the **main query** | — | — | one `:text` box should search several columns |
| `options` | the **input** | — | `[{label, value}]` | a fixed or computed choice list |
| `load` | the **option list** | `query, state` | `query` | the choices must be scoped (by site, by parent filter) |
| `apply` | the **main query** | `query, value, state` | `query` | the value does not map to a plain equality |
| `display_field` | the **option label** | `record`, or `record, state` | string | the label is composed, or differs by role |
| `preload` | the option **records** | — | — | `display_field` reads a relationship |

Read it as two halves: `options` / `load` / `display_field` / `preload` decide **what the reader
can pick**; `source` / `fields` / `apply` decide **what picking it does**.

> `apply` here is `fn query, value, state -> query`. On a **form field** the same name is
> `fn value, changeset, state -> changeset` ([../form/fields.md](../form/fields.md)). They are not
> interchangeable.

`mode` is a third axis — it decides *how the options arrive*: `:static` loads all of them,
`:load_more` pages, `:search` / `:search_multi` query as the reader types. `min_chars` and
`page_size` only matter for the paginated modes.

A `:relation` filter that declares `options` has no resource behind it: the list is loaded whole,
searched in memory by label or value, and its values are strings. That is the searchable
multi-select for a list the database does not hold as rows:

```elixir
filter :language, :relation do
  mode :search_multi
  min_chars 1
  options fn -> MyApp.Languages.options() end   # [{"EN", "en"}, {"FA", "fa"}]
end
```

## Rules the compiler enforces

- A `filters do … end` block must define at least one filter.
- `depends_on` must name a filter declared in the same table.
- A `:relation` filter in `:static` mode loads **all** options — the target's read action must not
  require pagination.
- A function `display_field` must be paired with `search_field` (there is no field to search on
  otherwise).

## TODO
- [ ] Function `display_field` paired with `search_field`
- [ ] `virtual true` paired with `resource` and `apply`
- [ ] `depends_on` names a real filter, and the child's `load` reads it from `state.filter_values`
- [ ] `:static` relation targets have non-required pagination — or use `:search` / `:load_more`
- [ ] `options fn` is cheap; it runs on every mount
- [ ] `visible` / `restricted` functions have arity **1**

**Schema:** `MishkaGervaz.Table.Entities.Filter`, `.Filter.Ui`, `.Filter.Preload` ·
**Verifier:** `Table.Verifiers.ValidateFilters` · **Types:** `MishkaGervaz.Table.Types.Filter`
