# Table → `url_sync`

Which table state round-trips through the URL, so a view can be bookmarked, shared, and
deep-linked into.

```elixir
url_sync do
  enabled true
  mode :bidirectional            # :read_only (default) | :bidirectional
  params [:filters, :sort, :page, :search]     # also :page_size, :template
  prefix "posts"
  max_filter_length 500
  preserve_params :all           # or [:tab] — kept in the URL, never stored in table state
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `enabled` | bool | `true` | |
| `mode` | `:read_only` \| `:bidirectional` | `:read_only` | `:read_only` reads the URL on load only |
| `params` | subset of `[:filters, :sort, :page, :page_size, :search, :template]` | `[:filters, :sort, :page]` | |
| `prefix` | string | — | namespaces every param |
| `max_filter_length` | pos int | `500` | longer values are ignored |
| `preserve_params` | `:all` \| `[atom]` | — | unknown params kept across re-encoding |

## Param format

```
?<prefix>_filter_<name>=value
&<prefix>_sort=name:asc
&<prefix>_page=2
&<prefix>_page_size=50
&<prefix>_search=hello
&<prefix>_template=grid
```

With `:search` in `params`, a filter named `:search` is written as `<prefix>_search` only, never
again as `<prefix>_filter_search`; without it, the search filter is a `filter_` param like any other.

With `:template` in `params`, `<prefix>_template` is the `name/0` of the template the table shows,
written as the reader switches. A URL naming one of the table's `switchable_templates` opens the
table in it, at mount and on a patch or the Back button; a name it does not offer opens the table's
own template. The URL's template wins over a `template` the mount passes.

A page or page size that is not a positive whole number reads as missing. The table opens a page
only when the database can read it: `(page - 1)` times its page size fits a signed 64-bit integer,
the range Postgres takes for `OFFSET`. Any other page opens page 1, and a `:bidirectional` table
writes the URL without it. A page past the last row opens, and shows no rows. A `:load_more` or
`:infinite` table opened at page N shows every row up to it, as the reader had them, and Load more
goes on with page N + 1 (see [pagination.md](pagination.md)).

The table sorts by the URL's sort fields that it sorts by itself: a sortable column's `sort_field`
(or its name) or a field of `default_sort`. A field the resource does not have, or a column that is
not `sortable`, is left out. A sort that keeps no field opens the table's own sort, and a
`:bidirectional` table writes the URL without it.

A distinct `prefix` per table is what lets two tables share one page — and lets another page
deep-link into this one:

```elixir
push_navigate(socket, to: "/admin/dashboard/blog/comments?comments_filter_post_id=#{post_id}")
```

The reader can then clear that filter like any other, because it *is* one.

## The parent LiveView decodes

```elixir
def handle_params(params, uri, socket) do
  url_state = MishkaGervaz.Table.Web.UrlSync.decode(params, uri, MyApp.Blog.Post)
  {:noreply, assign(socket, :url_state, url_state)}
end
```

and passes `url_state={@url_state}` to the component. `decode/3` reads the resource's own
`url_sync` config — prefix, allowed params, allowed filters, max length — so nothing is repeated.
`decode/4` takes overrides: `allowed_params`, `allowed_filters`, `max_filter_length`, `prefix`.
It returns `nil` when the resource has URL sync disabled. Full flow: [../mounting.md](../mounting.md).

The table applies each URL once. The page rendering it again with the same `url_state` — a
PubSub event, a rail or a flash of its own — leaves the reader's filters, sort and page as they
are, even while their load is running. A URL the reader goes to — a link, a patch, Back — is
applied.

## TODO
- [ ] Unique `prefix` per table appearing on the same page
- [ ] Parent calls `UrlSync.decode/3` in `handle_params` and assigns `:url_state`
- [ ] `:bidirectional` only where the URL should change as the reader filters
- [ ] `:page_size` added to `params` only if a page-size dropdown exists (`max_page_size` clamps it)
- [ ] `preserve_params` set if the page carries params of its own

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.url_sync`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-url_sync)

- Domain — [`mishka_gervaz.table.url_sync`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-url_sync)

**Schema:** `MishkaGervaz.Table.Dsl.UrlSync` (resource), `Table.Dsl.Defaults` (domain) ·
**Runtime:** `MishkaGervaz.Table.Web.UrlSync`
