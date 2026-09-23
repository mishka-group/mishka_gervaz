# Mounting the components

Two `Phoenix.LiveComponent`s. The DSL supplies everything; the parent LiveView supplies the actor,
decodes the URL, and answers a handful of messages.

## Table

```heex
<.live_component
  module={MishkaGervaz.Table.Web.Live}
  id="posts-table"
  resource={MyApp.Blog.Post}
  current_user={@current_user}
  url_state={@url_state}
/>
```

| Assign | Required | Note |
|---|---|---|
| `id` | ✔ | must match the id used by `send_update/2` |
| `resource` | ✔ | an Ash resource with `MishkaGervaz.Resource` |
| `current_user` | ✔ | the actor |
| `url_state` | — | from `UrlSync.decode/3`; `nil` disables URL sync for this mount |
| `template` | — | mount-time override: a template module, or the `name/0` of one in `switchable_templates` |
| `switchable_templates` | — | mount-time override of the switcher list |
| `url_sync` | — | `false` stops this mount patching the address bar; `url_state` (and its `path_params`) still applies. For a table inside a page that owns its own URL |

`template` / `switchable_templates` / `url_sync` are applied **at init only** — a later parent render will not
drag back a choice the reader has since changed.

## Form

```heex
<.live_component
  module={MishkaGervaz.Form.Web.Live}
  id={MishkaGervaz.Resource.Info.Form.component_id(MyApp.Blog.Post)}
  resource={MyApp.Blog.Post}
  current_user={@current_user}
  record_id={@post_id}
/>
```

| Assign | Required | Note |
|---|---|---|
| `id` | ✔ | use `FormInfo.component_id(Resource)` |
| `resource` | ✔ | |
| `current_user` | ✔ | |
| `record_id` | — | `nil` ⇒ create mode; set ⇒ edit mode |
| `defaults` | — | `%{site_id: @site_id}` — pre-fills create mode and fills params a hidden field would have carried |
| `hidden_fields` | — | `[:site_id]` — fields **this mount** does not draw |
| `submit` | — | `false` draws no submit row (the `save` event stays allowed) |
| `submit_alternatives` | — | other ways to create, offered from a caret beside the submit button |

Changing `record_id` or `defaults` re-initializes the form. The other three are applied **at init
only**.

### `hidden_fields` + `defaults` go together

A hidden field's value still reaches the save — but only if something supplies it. Pair every
hidden field the action requires with a `defaults` entry, or the save arrives without it.

### `submit_alternatives`

Only in **create** mode. Each entry is a map with `:id`, `:label`, optional `:description`, and
then either:

- `:navigate` — a path. The item is a link: it **leaves without submitting**, so no validation and
  no record. Right when the other way collects its own details elsewhere.
- `:name` and `:value` — the item is a submit button of this same form, so the browser sends the
  pair alongside every field and the choice reaches `before_save` as an ordinary param.

## Messages the parent must answer

### Form

```elixir
def handle_info({:form_saved, :create, result}, socket), do: …
def handle_info({:form_saved, :update, result}, socket), do: …
def handle_info({:form_cancelled, resource}, socket), do: …
def handle_info({:form_event, event, params}, socket), do: …   # any unrecognized form event
```

### Table

```elixir
def handle_info({:row_action, event_name, payload}, socket), do: …    # :event row actions
def handle_info({:bulk_action, action_name, selected_ids}, socket), do: …  # handler :parent
def handle_info({:expand_row, id}, socket), do: …                     # :accordion row actions
def handle_info({:show_modal, id}, socket), do: …
def handle_info({:edit_modal, id}, socket), do: …
def handle_info({:show_versions, id}, socket), do: …
def handle_info({:table_event, event, params}, socket), do: …        # any unrecognized table event
def handle_info({:put_flash, kind, message}, socket) do              # the BulkActionHooks bridge
  {:noreply, put_flash(socket, kind, message)}
end
```

A `:edit` row action needs **no** message handling: the component calls
`send_update(MishkaGervaz.Form.Web.Live, id: FormInfo.component_id(resource), record_id: id)`
itself. Add a `js` on the action to open the modal, and nothing else.

## `send_update` — what the table accepts back

```elixir
send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", pubsub_notification: notification)
send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", gervaz_refresh: true)
send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", expanded_html: html)
send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", expanded_error: reason)
```

## URL sync

```elixir
alias MishkaGervaz.Table.Web.UrlSync

def handle_params(params, uri, socket) do
  {:noreply, assign(socket, :url_state, UrlSync.decode(params, uri, MyApp.Blog.Post))}
end
```

`decode/3` reads the resource's own `url_sync` config — prefix, allowed params, allowed filters,
max length — and returns `nil` when URL sync is disabled. `decode/4` takes overrides:
`allowed_params`, `allowed_filters`, `max_filter_length`, `prefix`. Details:
[table/url-sync.md](table/url-sync.md).

## Realtime

The component subscribes itself; broadcasts land on the LiveView. Forward them:

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

## Auto-refresh

```elixir
def handle_info(:gervaz_refresh, socket) do
  send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", gervaz_refresh: true)
  {:noreply, socket}
end
```

## Expandable rows

```elixir
def handle_info({:expand_row, id}, socket) do
  send_update(MishkaGervaz.Table.Web.Live, id: "posts-table", expanded_html: render_panel(id))
  {:noreply, socket}
end
```

## Modals

Two ways to close a modal after save — pick **one**:

1. **Form `js` hooks** — `js do after_save fn _id -> hide_modal("post-form-modal") end end`.
   Pushed as a `"gervaz:exec-js"` browser event; needs a client-side listener.
2. **Parent messages** — handle `{:form_saved, …}` / `{:form_cancelled, …}` and push the JS
   yourself:

   ```elixir
   defp close_modal(socket, id) do
     push_event(socket, "gervaz:exec-js", %{target: id, js: Jason.encode!(hide_modal(id).ops)})
   end
   ```

Keep both modals rendered rather than wrapping them in `:if` — a modal removed from the DOM cannot
run its own exit transition.

## TODO — every mount
- [ ] `id` stable and matching every `send_update/2` call site
- [ ] Form id from `FormInfo.component_id/1`, not a literal
- [ ] `current_user` passed (the whole master/tenant split depends on it)
- [ ] `handle_params` decodes `url_state` if the table declares `url_sync`
- [ ] PubSub broadcasts forwarded if the table declares `realtime`
- [ ] `:gervaz_refresh` forwarded if the table declares `refresh`
- [ ] `{:put_flash, kind, msg}` bridge present if any bulk hook flashes
- [ ] `{:row_action, …}` / `{:bulk_action, …}` handled for every `:event` / `:parent` action
- [ ] `hidden_fields` paired with `defaults`
- [ ] Modal closing driven by exactly one of the two mechanisms

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Modules:** `MishkaGervaz.Table.Web.Live`, `MishkaGervaz.Form.Web.Live`,
`MishkaGervaz.Table.Web.UrlSync`, `MishkaGervaz.Table.Web.Refresh`
