# Table → `realtime`

PubSub-driven live updates. An entity — inline (`realtime prefix: "posts"`) or block form.

```elixir
realtime do
  enabled true
  prefix "blog_post"                       # REQUIRED whenever enabled
  pubsub MyApp.PubSub                      # normally set once on the domain
  visible fn record, user -> is_nil(user.site_id) or record.site_id == user.site_id end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `enabled` | bool | `true` | |
| `prefix` | string | — | topic prefix — `"posts"` ⇒ `posts:created`, … |
| `pubsub` | `Phoenix.PubSub` module | — | usually inherited from the domain |
| `visible` | `fn record, user -> boolean` | — | arity **2** — filters incoming updates |

`enabled false` on a resource **beats** `true` on the domain: `false` is an answer, not an absence.

## The parent LiveView still has one job

The component subscribes itself, but broadcasts arrive at the **LiveView** process. Forward them:

```elixir
def handle_info(
      %Phoenix.Socket.Broadcast{
        topic: "blog_post" <> _,
        payload: %Ash.Notifier.Notification{} = notification
      },
      socket
    ) do
  send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", pubsub_notification: notification)
  {:noreply, socket}
end
```

Full integration: [../mounting.md](../mounting.md).

## `visible` keeps other tenants out

Without it a master's broadcast can insert a row a tenant must not see. The predicate runs per
incoming record against the current user.

To take control of an update entirely, use the `on_realtime` hook and return `{:halt, socket}`
([hooks.md](hooks.md)).

## The total follows

After each notification it handles, the table counts its total again with its own read —
filters, search, `path_params`, `on_load`, the archive view's action and the tenant — so
"Showing N", the page count and the empty state follow rows added and removed, and a notification
delivered twice counts once. The count runs as a task, one per burst of notifications; an empty
table counts at once, so its first row arrives with its total. A numbered table left past its last
page loads the last page.

A row that arrives or changes over realtime is read with the same read, filtered to that row, before
it is shown (`DataLoader.rows_in_view/2`): one read, with its preloads, both says whether the row is
in the view and draws it. One that does not match the filters, search or `path_params` is not
inserted, and one edited out of them leaves the list, closing its expanded row if it had one. A
manual read, which cannot be asked about one row, or a read that returns an error, shows every row
as it arrives.

A burst of notifications is read together. The table answers the first with a message to itself,
so the rest of the burst, such as one notification per row of a bulk action, arrives first, and one
read, `max_page_size` rows at a time, places every row of it. While the table loads its rows afresh
— the reload after its own bulk action, a filter, a sort — a burst reads nothing: that load draws
the rows, and the total is counted once it lands.

A row the list already shows is drawn again in its place; a new one goes first. A table with
`keep_loaded_records true` does the same to `state.loaded_records`, so a template drawn from them
shows the change too, and a row that leaves the list leaves them.

Only a table that keeps a count follows: `:numbered`, or any type with `show_total true` (the
default). A `:load_more` / `:infinite` table with `show_total false` changes neither its total nor
its empty state over realtime — use `show_total true` where rows arrive live.

A hook that halts and changes rows itself asks for the same:

```elixir
on_realtime fn notification, socket ->
  {:halt,
   socket
   |> redraw_rows(notification)
   |> MishkaGervaz.Table.Web.DataLoader.refresh_total()}
end
```

## TODO
- [ ] `prefix` set (compile fails otherwise)
- [ ] `pubsub` reachable — set on the domain
- [ ] Resource's Ash `pub_sub` notifier actually broadcasts on that prefix
- [ ] Parent LiveView forwards `%Phoenix.Socket.Broadcast{}` via `send_update/2`
- [ ] `visible` declared for any multitenant resource
- [ ] `enabled false` on tables backed by a data layer with nothing to subscribe to
- [ ] An `on_realtime` that halts and adds or removes rows calls `DataLoader.refresh_total/1`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.realtime`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-realtime)

- Domain — [`mishka_gervaz.table.realtime`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-realtime)

**Schema:** `MishkaGervaz.Table.Dsl.Realtime`, `MishkaGervaz.Table.Entities.Realtime` ·
**Verifier:** `Table.Verifiers.ValidateSource`
