# MishkaGervaz — Table Rules

The `table` section builds an admin list view: query, filters, sort, pagination, row actions,
bulk actions, realtime, archive and URL state. Read [../usage-rules.md](../usage-rules.md) first —
master/tenant, the three slots (`source` / `ui` / `render`), and predicate arities are assumed
everywhere below.

**This file is an index.** Open only the section you are editing.

## Skeleton — the full section list, in DSL order

```elixir
mishka_gervaz do
  table do
    identity do … end
    source do … end
    columns do … end
    filters do … end
    filter_groups do … end
    row_actions do … end
    row do … end
    bulk_actions do … end
    layout do … end
    presentation do … end
    hooks do … end
    refresh do … end
    url_sync do … end
    state do … end

    realtime do … end          # entities, not sections — also take inline keyword form
    pagination do … end
    empty_state message: "…"
    error_state message: "…"
    data_loader do … end
    events do … end

    view :refunds do … end      # named views: other columns and a base filter, picked per mount
  end
end
```

Entities also take inline form: `pagination type: :infinite, page_size: 25` ·
`realtime prefix: "posts"` · `empty_state message: "None", icon: "hero-inbox"`.

## Sections

| Section | What it decides | Rules |
|---|---|---|
| `identity` | the table's name, its base route, and the path params that become filters | [table/identity.md](table/identity.md) |
| `source` | which Ash actions run, what is preloaded, whether archive is on | [table/source.md](table/source.md) |
| `columns` | the cells: value source, sorting, static/computed columns, cell types, auto-discovery | [table/columns.md](table/columns.md) |
| `filters` | the filter inputs and how each one narrows the query | [table/filters.md](table/filters.md) |
| `filter_groups` | which filters sit in which collapsible panel | [table/filter-groups.md](table/filter-groups.md) |
| `row_actions` | per-row buttons, dropdowns, and which are inline vs collapsed | [table/row-actions.md](table/row-actions.md) |
| `row` | selection checkboxes, row click, per-row classes, whole-row overrides | [table/row.md](table/row.md) |
| `bulk_actions` | what can be done to a selection, and who executes it | [table/bulk-actions.md](table/bulk-actions.md) |
| `pagination` | numbered / load-more / infinite, page sizes, and the labels around them | [table/pagination.md](table/pagination.md) |
| `realtime` | the PubSub topic the table subscribes to, and which records it accepts | [table/realtime.md](table/realtime.md) |
| `url_sync` | which state round-trips through the URL, under which prefix | [table/url-sync.md](table/url-sync.md) |
| `refresh` | the auto-reload timer and when it pauses | [table/refresh.md](table/refresh.md) |
| `layout` | the chrome: header, footer, and positioned notices | [table/layout.md](table/layout.md) |
| `presentation` | template vs UI adapter, features, theme, responsive, template switching | [table/presentation.md](table/presentation.md) |
| `empty_state` / `error_state` | what fills the table when there is nothing, or something broke | [table/states.md](table/states.md) |
| `hooks` | lifecycle callbacks, per-action observers, full action overrides, built-in transitions | [table/hooks.md](table/hooks.md) |
| `view` | a named table over the same resource, with its own columns and base filter | [table/views.md](table/views.md) |
| `state` / `data_loader` / `events` | replacing a builder, loader or event handler | [customization/overrides.md](customization/overrides.md) |

## The five things that fail a build

1. `identity` needs **`name` and `route`** as soon as any column / filter / row action / bulk action exists.
2. `source.actions.read` is required; `get` once rows are interactive; `destroy` once a `:destroy` action exists.
3. `static true` columns need `requires`, and `sort_field` too if they are `sortable`.
4. `archive` and `AshArchival.Resource` must both be present, or neither.
5. `realtime` needs a `prefix` while enabled.

Full error text and the fix for each: [troubleshooting.md](troubleshooting.md).

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table)

- Domain — [`mishka_gervaz.table`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table)
