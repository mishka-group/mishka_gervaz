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

## Page events

The pager's `go_to_page` and `change_page_size` events read their page and size the way the URL
does. A `go_to_page` whose page is not a positive whole number opens page 1; a counted table holds
it to its last page, and a table that keeps no count opens it when the database can read its offset
(see [url-sync.md](url-sync.md)) and opens page 1 when it cannot. A `change_page_size` whose size is
not a positive whole number is ignored. A custom `events do sanitization … end` handler's
`sanitize_page/1` returns the number, or `nil` for anything else.

## Load more reads after the last row

Load more and infinite scroll read the page after the last row the table read, by its keyset
(`state.after_keyset`), when the table's read action allows keyset pagination:

```elixir
read :master_read do
  pagination offset?: true, keyset?: true, countable: true
end
```

A row added or removed anywhere in the list, by this view, another one or realtime, then moves no
row past Load more and takes no row from its page, in the same one read. Keep `offset?: true` too:
a numbered page and a page opened from the URL are read by offset.

Keyset is optional. Without `keyset?: true`, or when Ash refuses the keyset as invalid, Load more
reads from the offset of the rows the view shows: `state.next_offset`, one less for each row
realtime, the view or a custom action takes out of the list (after the rows kept, with
`keep_loaded_records true`). No row is skipped there either; a row that leaves without having been
shown, or one that arrives, only makes that click read a row already shown again, so it adds fewer
new rows.

## Load earlier

A `:load_more` / `:infinite` table keeps its last page in the URL (`?<prefix>_page=N`), so a reload
after Load more opens page N alone, never pages 1..N. A Load earlier button above the rows then
reads the page before the first row shown, by its keyset (`state.before_keyset`), and puts it
above: one page and one read a click, until the first page. `state.first_page` is the first page
shown; `state.page` stays the last. Without keyset it reads that page's slice by offset. A table with
`keep_loaded_records true` reads pages 1..N on open, so it never offers one.

## The footer

Every pager is one row (`Shared.render_pagination_row/1`): the page size selector first, the page
buttons or Load More in the middle, and last where the reader is. A numbered table shows its
`page_info_format` there, a `:load_more` / `:infinite` table the rows it shows of its total,
`Showing 1–40 of 136` (`Shared.range_label/1`): from the first row shown, so a list opened at page
3 starts at 41, to `state.next_offset`. Both need `show_total`, and read only the state, so the
footer adds no query. Below 640px the three parts stack, each centred.

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
- [ ] The read action of a `:load_more` / `:infinite` table allows `keyset?: true` where rows change
  live, so every Load more adds a full page

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.pagination`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-pagination) · [`mishka_gervaz.table.pagination.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-pagination-ui)

- Domain — [`mishka_gervaz.table.pagination`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-pagination) · [`mishka_gervaz.table.pagination.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-pagination-ui)

**Schema:** `MishkaGervaz.Table.Entities.Pagination`, `.Pagination.Ui` ·
**Verifiers:** `Table.Verifiers.ValidatePagination`, `.ValidateDomainDefaults`
