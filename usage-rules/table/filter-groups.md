# Table → `filter_groups`

Organises filters that already exist into collapsible panels. Independent of where the filters
are declared — a group only names them.

```elixir
filter_groups do
  group :primary do
    filters [:search]
    collapsible false
  end

  group :advanced do
    filters [:status, :language, :contributor, :created_at, :updated_at]
    collapsible true
    collapsed true

    ui do
      label fn -> dgettext("mishka_gervaz", "Advanced Search") end
      icon "hero-funnel"
      columns 3
    end
  end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `filters` | `[atom]` | — | **required** |
| `collapsed` | bool | **`true`** | note the default — a group starts closed |
| `collapsible` | bool | `false` | whether the user may toggle it |
| `visible` / `restricted` | bool \| `fn state ->` | `true` / `false` | arity **1** |
| `position` | int \| `:first` \| `:last` | — | |

`ui`: `label` · `icon` · `description` · `class` · `header_class` · `columns` (1..6, default 3, drawn by a collapsible group only) · `extra`.

Compile fails if a group names a filter that does not exist, or if one filter appears in two
groups.

## TODO
- [ ] Every referenced filter is declared in `filters`
- [ ] No filter appears in two groups
- [ ] `collapsed` set deliberately — it defaults to `true`
- [ ] `collapsible true` wherever `collapsed true` is set, or the user can never open it

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.filter_groups`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filter_groups) · [`mishka_gervaz.table.filter_groups.group`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filter_groups-group) · [`mishka_gervaz.table.filter_groups.group.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-filter_groups-group-ui)

**Schema:** `MishkaGervaz.Table.Entities.FilterGroup`, `.FilterGroup.Ui` ·
**Verifier:** `Table.Verifiers.ValidateFilters`
