# Table → `empty_state` / `error_state`

What fills the table when there is nothing to show, or the load failed. Both are entities —
inline or block form.

```elixir
empty_state message: "No blog posts found",
            icon: "hero-newspaper",
            action_label: "New post",
            action_path: "/admin/dashboard/blog/posts/new",
            action_icon: "hero-plus"

error_state message: "Failed to load posts",
            icon: "hero-exclamation-triangle",
            retry_label: "Retry"
```

Block form is identical:

```elixir
empty_state do
  message "No media files found"
  icon "hero-photo"
end
```

## `empty_state`

| Option | Type | Default |
|---|---|---|
| `message` | string | `"No records found"` |
| `icon` | string | — |
| `action_label` | string | — |
| `action_path` | string | — |
| `action_icon` | string | — |

The three `action_*` options draw one call-to-action link. Give all three or none.

A page past the table's last one, as `?<prefix>_page=999` or a stale link opens it on a numbered or
a Load more table, draws the empty state too, saying "No rows on this page" with a "Go to page 1"
button in place of the message and action above
(`MishkaGervaz.Table.Web.Renderer.past_last_page?/1`). An adapter's `empty_state` draws that button
from its `action_click` assign, a `Phoenix.LiveView.JS` command; a template that draws its own empty
state asks `past_last_page?/1` itself.

## `error_state`

| Option | Type | Default |
|---|---|---|
| `message` | string | `"Error loading data"` |
| `icon` | string | — |
| `retry_label` | string | `"Retry"` |

It shows when the table's first load fails, in place of the rows: the header, filters, template
switcher and notices stay, so the reader can change what failed. Retry loads the first page again
with the same filters, sort and search. The exception goes to the log, never to the page. A load
that fails after one has succeeded keeps the rows already on screen.

## Empty vs "no match"

`empty_state` is the whole-table empty. A **filtered** empty ("nothing matches your filters") is
better said with a notice bound to `:no_results`, which can carry its own wording and a hint to
clear the filters — see [layout.md](layout.md).

## TODO
- [ ] Both messages written for the reader, not the developer
- [ ] `empty_state` action wired to a real route, or omitted
- [ ] A `:no_results` notice added where the filtered-empty case reads differently
- [ ] Messages via `dgettext("mishka_gervaz", …)` in a localized app

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.empty_state`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-empty_state) · [`mishka_gervaz.table.error_state`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-error_state)

**Schema:** `MishkaGervaz.Table.Dsl.States`, `Table.Entities.EmptyState`, `.ErrorState`
