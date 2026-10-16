# Table → `pagination`

An entity, not a section — inline (`pagination type: :infinite, page_size: 25`) or block form.

```elixir
pagination do
  type :load_more                  # :numbered | :load_more | :infinite
  page_size 20
  page_size_options [20, 50, 100, 150]
  max_page_size 150
  enabled true                     # false disables pagination, overriding the domain

  ui do
    load_more_label "Load More"
    loading_text "Loading..."
    show_total true
    prev_label "Previous"
    next_label "Next"
    first_label "First"
    last_label "Last"
    page_info_format "Page {page} of {total}"   # {page} {total} {count}
  end
end
```

## Defaults after the domain merge

`type: :load_more` · `page_size: 20` · `max_page_size: 150` · `page_size_options: nil`
(no page-size dropdown). Every key is inheritable from the domain, resource wins per key.

## Compile-checked rules

- `page_size` must be a positive integer.
- Every entry in `page_size_options` must be a positive integer.
- `page_size` must be a **member of** `page_size_options` when both are set.
- `max_page_size` must be **≥ the largest** `page_size_options` entry.
- `type` must be one of the three atoms.

`max_page_size` also clamps a page size arriving from the URL — it is the guard against
`?t_page_size=100000`.

## `show_total` costs a COUNT

`show_total` defaults to **true** and issues a count query. Turn it off for a data layer that
cannot count (`Ash.DataLayer.Simple` raises "Aggregate queries not supported"), or where the
design shows no total:

```elixir
pagination do
  type :load_more
  page_size 30
  ui do show_total false end
end
```

## TODO
- [ ] `page_size ∈ page_size_options`
- [ ] `max_page_size ≥ max(page_size_options)`
- [ ] `show_total false` when the data layer cannot count
- [ ] `:load_more` / `:infinite` chosen for lists that are scrolled, `:numbered` for lists that are paged
- [ ] A grouped custom template also sets `presentation.keep_loaded_records true`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.pagination`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-pagination) · [`mishka_gervaz.table.pagination.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-pagination-ui)

- Domain — [`mishka_gervaz.table.pagination`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-pagination) · [`mishka_gervaz.table.pagination.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-pagination-ui)

**Schema:** `MishkaGervaz.Table.Entities.Pagination`, `.Pagination.Ui` ·
**Verifiers:** `Table.Verifiers.ValidatePagination`, `.ValidateDomainDefaults`
