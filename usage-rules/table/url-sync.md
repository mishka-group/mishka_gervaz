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
