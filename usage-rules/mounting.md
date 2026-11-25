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
| `view` | — | the name of a `view` of the resource's table to draw instead of the table's own columns, see [table/views.md](table/views.md) |
| `template` | — | mount-time override: a template module, or the `name/0` of one in `switchable_templates` |
| `switchable_templates` | — | mount-time override of the switcher list |
| `url_sync` | — | `false` stops this mount patching the address bar; `url_state` (and its `path_params`) still applies. For a table inside a page that owns its own URL |

`view` / `template` / `switchable_templates` / `url_sync` are applied **at init only** — a later parent render will not
drag back a choice the reader has since changed.

### Slots

| Slot | Drawn |
|---|---|
| `rail` | beside the table, under its filters |
| `before_table` | above the rows |
| `filter_actions` | at the end of the filter bar |
| `table_footer` | under the rows, by the default table template, given the table's counts |

`table_footer` receives `%{shown: shown, total: total, more?: more?, loading?: loading?}` — the
rows the view shows, the rows the read finds under its filters (`nil` when the table keeps no
count), whether rows are left for Load more and whether a read runs — and carries the page's own
text and buttons. It is not drawn while the table has nothing to show or its first read failed:

```heex
<.live_component module={MishkaGervaz.Table.Web.Live} id="products" …>
  <:table_footer :let={counts}>
    <span>{counts.shown} of {counts.total} products</span>
    <button phx-click="new_product">Add product</button>
  </:table_footer>
</.live_component>
```

A custom template reads the counts with `MishkaGervaz.Table.Templates.Shared.table_counts/1`.

A page's own button loads the next page with `MishkaGervaz.Table.Web.Live.load_more/2`, the JS the
table's Load more runs; chain the page's own push before it when the page keeps count of presses:

```heex
<:table_footer :let={counts}>
  <span>{counts.shown} of {counts.total} orders</span>
  <button :if={counts.more?} phx-click={JS.push("older") |> MishkaGervaz.Table.Web.Live.load_more("orders")}>
    Load older orders
  </button>
</:table_footer>
```

`pagination do ui do load_more_at :footer end end` moves the table's own Load more to the end of
this row instead ([table/pagination.md](table/pagination.md)).

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
| `defaults` | — | `%{site_id: @site_id}` — pre-fills create mode and fills params a hidden field would have carried; a field the author empties is saved empty, and a picker's default is left out once the picker is cleared or emptied by a change to one it depends on |
| `hidden_fields` | — | `[:site_id]` — fields **this mount** does not draw |
| `submit` | — | `false` draws no submit row (the `save` event stays allowed) |
| `submit_alternatives` | — | other ways to create, offered from a caret beside the submit button |
| `notify_dirty` | — | `true` sends the page `{:form_dirty, id, dirty?}` — see "Unsaved changes" |
| `notify_failed` | — | `true` sends the page `{:form_failed, id, failure}` on each refused save — see "After a refused save" |
| `:body` slot | — | the page places the groups in its own markup — see "Placing the groups in the page" |

Changing `record_id` or `defaults` re-initializes the form. The others are applied **at init
only**. An update that leaves `defaults` out, such as the `send_update/2` a table's Edit sends with
only a `record_id`, keeps the defaults the form has; pass `defaults: nil` to drop them.

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

### Placing the groups in the page

A `:standard` form draws its groups one after another. A page that puts them in its own cards or
numbered steps, with markup of its own between them, passes a `:body` slot and calls `group/1`
where each group goes:

```heex
<.live_component module={MishkaGervaz.Form.Web.Live} id="post-form" resource={MyApp.Post}
  current_user={@current_user} record_id={@post_id}>
  <:body :let={form}>
    <section class="card"><MishkaGervaz.Form.Web.Live.group form={form} name={:basics} /></section>
    <section class="card">The page's own content.</section>
    <section class="card"><MishkaGervaz.Form.Web.Live.group form={form} name={:publishing} /></section>
  </:body>
</.live_component>
```

- It is **one form**: the slot sits inside the one `<form>`, so one changeset, one save, a field's
  error in its own group, unsaved changes and Discard as before. The submit row, form errors and
  uploads stay after the slot; the fields in no group are drawn there too.
- The page's markup in the slot is inside that `<form>`: no `<form>` of its own, and no named input
  that is not the form's. Its events go to the page unless they name a `phx-target`.
- While the form loads, or when the reader may not use it, the slot is still drawn and each group
  shows the loading state or nothing, so the page around them stays.
- A group the page leaves out is not drawn; a name the form has no group for raises.
- `:wizard` and `:tabs` forms ignore the slot.

### Unsaved changes

The form's wrapper, `"<id>-form-wrapper"`, carries `data-dirty="true"` while the form holds changes
the reader has not saved. Mounted with `notify_dirty={true}`, the form also tells its page each
time that changes, so the page can ask before it closes the form's window:

```elixir
def handle_info({:form_dirty, "post-form", dirty?}, socket),
  do: {:noreply, assign(socket, :post_form_dirty?, dirty?)}
```

It is sent once the form holds changes, and again once it holds none: after a save, a Discard, a
Cancel or a start over. A page that did not ask is never sent it. A form in the UI adapter's
`drawer` or `sheet` hands it on as `confirm_close`, so closing the window asks "Discard your
changes?" first ([customization/ui-adapters.md](customization/ui-adapters.md)). A `cancel` or `discard` button
declared with `confirm` asks its question itself while the form holds changes
([form/submit.md](form/submit.md)).

### After a refused save

A refused save keeps what was typed, shows each message under its field, and moves the reader to
the first field with an error, in the order the form draws them: the field is focused, which
scrolls it into view, and a collapsed group or another step holding it is opened first. A refusal
no field shows moves the reader to the message above the submit row. It is `Phoenix.LiveView.JS`
in the template (a hidden mark per refusal with `phx-mounted`), so the page needs no hook. Each
field's cell is `"<id>-field-<name>"`.

Mounted with `notify_failed={true}`, the form also tells its page, for a toast:

```elixir
def handle_info({:form_failed, "post-form", %{fields: fields}}, socket) do
  new_socket = MishkaGervaz.Toast.push(socket, :error, "Check the #{length(fields)} marked fields.")
  {:noreply, new_socket}
end
```

`failure` is `%{mode: :create | :update, fields: [atom], messages: [String.t()]}`: the fields
showing an error, in the order the form declares them, and the messages above the submit row.

## Messages the parent must answer

### Form

```elixir
def handle_info({:form_saved, :create, result}, socket), do: …
def handle_info({:form_saved, :update, result}, socket), do: …
def handle_info({:form_cancelled, resource}, socket), do: …
def handle_info({:form_event, event, params}, socket), do: …   # any unrecognized form event
def handle_info({:form_dirty, id, dirty?}, socket), do: …       # only with notify_dirty={true}
def handle_info({:form_failed, id, failure}, socket), do: …     # only with notify_failed={true}
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

## Toasts

A page that tells the reader what just happened, "Order refunded.", keeps its toasts with
`MishkaGervaz.Toast`: `attach/1` once in `mount/3`, `toasts/1` drawn once, and `push/4` where
something happened. Each toast leaves by itself, through a timer message the hook answers in the
page's own process (5 seconds, 8 with an Undo or a link, or `ms:`), and at once on its Close; a page
keeps the four newest. A component of the page sends one with `send_toast/3`.

```elixir
def mount(_params, _session, socket), do: {:ok, MishkaGervaz.Toast.attach(socket)}

def handle_info({:form_saved, :update, product}, socket) do
  new_socket =
    MishkaGervaz.Toast.push(socket, :ok, "Product saved.",
      navigate: "/admin/products/#{product.id}",
      link_label: "Open it"
    )

  {:noreply, new_socket}
end

def handle_info({:row_action, "archive", %{"id" => id}}, socket) do
  # ... archive it
  {:noreply, MishkaGervaz.Toast.push(socket, :info, "Product archived.", undo: {:restore, id})}
end

def handle_info({:toast_undo, {:restore, id}}, socket), do: …   # the Undo was pressed
```

```heex
<MishkaGervaz.Toast.toasts toasts={@gervaz_toasts} ui={MyAppWeb.UIAdapter} />
```

Tones: `:ok`, `:info`, `:warn`, `:error`. A link is `navigate:` (inside the app) or `href:` (a
plain address, such as a file), with `link_label:`; an Undo is `undo:` (any term), with
`undo_label:`. The toasts live in the `:gervaz_toasts` assign; the UI adapter's `toast/1` draws each.

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

The UI adapter's `drawer` (a bottom sheet below 640px) and `sheet` are the gervaz panels for a form
or a page; they carry their own exit transition in `phx-remove`, so they may sit under an `:if`
([customization/ui-adapters.md](customization/ui-adapters.md)).

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
- [ ] A page that pushes toasts runs `MishkaGervaz.Toast.attach/1` in `mount/3` and draws
  `MishkaGervaz.Toast.toasts/1` once, and answers `{:toast_undo, undo}` for every Undo it offers

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Modules:** `MishkaGervaz.Table.Web.Live`, `MishkaGervaz.Form.Web.Live`,
`MishkaGervaz.Table.Web.UrlSync`, `MishkaGervaz.Table.Web.Refresh`
