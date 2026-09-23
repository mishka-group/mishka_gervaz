# Table → `hooks`

Four layers, in increasing order of force. Reach for the weakest one that does the job.

1. **Global lifecycle** — fires for every event of a kind.
2. **Per-action observers** — fire alongside the built-in handler for one named action. They
   cannot replace it; they observe and decorate.
3. **Full overrides** — replace the built-in handler for one named action.
4. **Built-in transitions** — opt-in flags for common post-action UX.

## 1. Global lifecycle

```elixir
hooks do
  on_load fn query, state -> {:cont, query} end
  before_delete fn record, state -> {:ok, state} end          # {:halt, {:error, msg}} refuses
  after_delete  fn record, state -> :ok end                    # side effects only
  on_realtime fn notification, socket -> {:cont, socket} end   # {:halt, socket} skips the update
  on_expand   fn record_id, socket -> {:cont, socket} end      # {:halt, socket} cancels
  on_filter   fn filter_values, socket -> socket end
  on_select   fn selected_ids, socket -> socket end
  on_sort     fn {field, direction}, socket -> socket end
  on_event    fn event_name, params, socket -> {:ok, socket} end
end
```

Most may return `socket`, `{:cont, socket}` or `{:halt, socket}`. `:halt` stops the built-in
behaviour.

An `on_realtime` that halts and adds or removes rows itself hands its socket through
`MishkaGervaz.Table.Web.DataLoader.refresh_total/1`, so "Showing N", the page count and the empty
state follow — see [realtime.md](realtime.md).

`on_load` is the query hook — it is also how a table is backed by something other than the
database:

```elixir
on_load fn query, state ->
  {:cont, Ash.DataLayer.Simple.set_data(query, rows(state))}
end
```

and how a route param scopes the list:

```elixir
on_load fn
  query, %{path_params: %{source_page_id: id}} when not is_nil(id) ->
    {:cont, Ash.Query.filter(query, is_nil(applied_at) and source_page_id == ^id)}

  query, _unscoped ->
    {:cont, Ash.Query.filter(query, false)}
end
```

## 2. Per-action observers

Keyed by the action's **name**. First argument is an atom or a list of atoms.

```elixir
before_row_action     :unarchive, fn record, state -> :ok end
after_row_action      :delete_draft, fn result, state -> {:ok, state} end
on_row_action_success :unarchive, fn result, state, socket -> socket end
on_row_action_error   :publish,   fn reason, state, socket -> socket end

before_bulk_action     :archive, fn ids, state -> :ok end
after_bulk_action      :archive, fn result, state -> :ok end
on_bulk_action_success :unarchive, fn summary, state, socket -> socket end
on_bulk_action_error   :destroy,   fn summary, state, socket -> socket end

before_row_action [:unarchive, :restore], fn record, state -> :ok end   # one hook, several actions
```

`on_*_success` / `on_*_error` accept arity **2 or 3**. Take the socket (arity 3) when you need
full control — `put_flash/3`, `push_navigate/2`, reloading. Arity 2 is enough for logging.

`before_*` refuses by returning `{:halt, {:error, message}}`.

### Flash control on bulk actions

An arity-3 bulk hook decides whether the core handler's **default** flash also fires:

```elixir
on_bulk_action_success :unarchive, fn summary, _state, socket ->
  socket
  |> MishkaGervaz.Table.Web.Events.BulkActionHooks.put_flash(:info,
       "Restored #{summary.succeeded_count} records.")
  |> MishkaGervaz.Table.Web.Events.BulkActionHooks.silence()   # {:halt, socket} — no default flash
end
```

- `silence(socket)` → `{:halt, socket}`; the hook owns all messaging.
- returning the plain `socket` → the default flash fires too (`use_default/1` says so explicitly).
- **`BulkActionHooks.put_flash/3`, not `Phoenix.LiveView.put_flash/3`.** The hook runs inside a
  LiveComponent, whose `@flash` the parent layout does not read; the helper sends
  `{:put_flash, kind, msg}` to the LiveView process instead. Your page needs the bridge:

  ```elixir
  def handle_info({:put_flash, kind, message}, socket), do: {:noreply, put_flash(socket, kind, message)}
  ```

## 3. Full overrides

Replace the built-in handler entirely:

```elixir
override_row_action  :fork, fn payload, state ->
  send(self(), {:draft_row_action, "fork_draft", payload["id"]})
  {:ok, state}
end

override_bulk_action :export, fn ids, state -> {:ok, state} end
```

Inside a LiveComponent, `self()` **is the parent LiveView process** — which is what makes `send/2`
the way to hand work back to the page.

## 4. Built-in transitions

```elixir
hooks do
  switch_to_active_on_empty_archive true      # default false
  switch_to_archive_on_empty_active true      # default false
  clear_selection_after_bulk true             # default TRUE
  reset_page_on_empty_current_page true       # default false
  redirect_on_empty "/admin/dashboard"        # string | fn state -> path
end
```

These cover the transitions people otherwise hand-write in three hooks: after the last archived
row is restored, show the active list again; after a bulk action, drop the selection; if a page
became empty, reload page 1.

## TODO
- [ ] The weakest layer that works: built-in flag → observer → override
- [ ] `before_*` returns `:ok` / `{:ok, state}` / `{:halt, {:error, msg}}` and nothing else
- [ ] Arity-3 chosen only where the socket is genuinely needed
- [ ] Bulk flashes use `BulkActionHooks.put_flash/3` + `silence/1`, and the page has the
      `{:put_flash, kind, msg}` bridge
- [ ] `on_load` returns `{:cont, query}`
- [ ] Every hook name matches a declared row/bulk action name
- [ ] `after_*` used for side effects only — it cannot change the outcome

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.hooks`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks) · [`mishka_gervaz.table.hooks.before_row_action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-before_row_action) · [`mishka_gervaz.table.hooks.after_row_action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-after_row_action) · [`mishka_gervaz.table.hooks.on_row_action_success`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-on_row_action_success) · [`mishka_gervaz.table.hooks.on_row_action_error`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-on_row_action_error) · [`mishka_gervaz.table.hooks.before_bulk_action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-before_bulk_action) · [`mishka_gervaz.table.hooks.after_bulk_action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-after_bulk_action) · [`mishka_gervaz.table.hooks.on_bulk_action_success`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-on_bulk_action_success) · [`mishka_gervaz.table.hooks.on_bulk_action_error`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-on_bulk_action_error) · [`mishka_gervaz.table.hooks.override_row_action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-override_row_action) · [`mishka_gervaz.table.hooks.override_bulk_action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-hooks-override_bulk_action)

**Schema:** `MishkaGervaz.Table.Dsl.Hooks`, `Table.Entities.ActionHook` ·
**Runtime:** `Table.Web.Events.HookRunner`, `.BulkActionHooks`, `.BulkActionResult`
