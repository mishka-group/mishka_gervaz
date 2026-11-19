# Table → `view`

A named table over the same resource: its own columns and a base filter, beside the table's own.
A mount picks it by name; a mount that names none draws the table itself.

```elixir
table do
  identity do
    name :orders
    route "/admin/orders"
  end

  columns do
    column :number
    column :customer
    column :total
  end

  view :refunds do
    filter expr(not is_nil(refunded_at))

    columns do
      default_sort refunded_at: :desc

      column :number
      column :refund_reason
      column :amount_refunded do
        label "Refunded"
      end
    end
  end
end
```

```heex
<.live_component
  module={MishkaGervaz.Table.Web.Live}
  id="refunds-table"
  resource={MyApp.Shop.Order}
  view={:refunds}
  current_user={@current_user}
/>
```

| Option | Type | Note |
|---|---|---|
| `filter` | Ash expression \| keyword list | applied to every read of the view, under the reader's own filters; the reader cannot clear it |
| `columns` | block | `column` entities, `column_order` and `default_sort`, as in the table's [`columns`](columns.md); no `auto_columns` |

## What a view keeps from the table

Everything but its columns and base filter: `identity`, `source` (the read action too),
`filters`, `row_actions`, `bulk_actions`, `pagination`, `realtime`, `url_sync` and
`presentation`. Rows still arrive through the stream, read async, page by page. A view preloads
what its own columns need, not what only the table's columns need.

## Rules

- A view declares at least one column, and its columns follow the table's column rules
  (`static` + `requires`, `sortable` + `sort_field`); `Table.Verifiers.ValidateColumns` checks both.
- `view={:name}` is read **at init only**. A name the resource does not declare raises
  `ArgumentError`.
- Two mounts of one resource on a page need different `id`s; each gets its own stream.

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.view`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-view) · [`mishka_gervaz.table.view.columns`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-view-columns)

**Schema:** `MishkaGervaz.Table.Dsl.Views`, `MishkaGervaz.Table.Entities.View` ·
**Runtime:** `MishkaGervaz.Table.Web.State.apply_view/2`, `MishkaGervaz.Resource.Info.Table.view/2`
