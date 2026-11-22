defmodule MishkaGervaz.Table.Web.Live do
  @moduledoc """
  LiveComponent for MishkaGervaz admin tables.

  This is a thin orchestrator that delegates to specialized modules:
  - `State` - State management
  - `DataLoader` - Async data loading with streams
  - `Events` - Event handling
  - `Renderer` - Template rendering

  ## Usage

  Minimal usage (all config from DSL):

      <.live_component
        module={MishkaGervaz.Table.Web.Live}
        id="posts-table"
        resource={MyApp.Post}
        current_user={@current_user}
      />

  Everything else comes from the DSL defined on your resource.

  ## Required Assigns

  - `id` - Unique component ID
  - `resource` - Ash resource module with `MishkaGervaz.Resource` extension
  - `current_user` - Current user for authorization

  ## Optional Assigns

  - `view` - The name of a `view` of the resource's table, drawn instead of the table's own
    columns, with its base filter; see `MishkaGervaz.Table.Dsl.Views`

  ## Slots

  - `rail` - drawn beside the table, under its filters
  - `before_table` - drawn above the rows
  - `filter_actions` - drawn at the end of the filter bar
  - `table_footer` - drawn under the rows by the default table template, given the table's counts,
    `%{shown: shown, total: total}` (`MishkaGervaz.Table.Templates.Shared.table_counts/1`); it may
    carry text and buttons of the page's own:

        <:table_footer :let={counts}>
          {counts.shown} of {counts.total} products
          <button phx-click="new_product">Add product</button>
        </:table_footer>

  ## Parent LiveView Integration

  The component sends messages to the parent for certain actions:

      def handle_info({:show_modal, id}, socket), do: ...
      def handle_info({:edit_modal, id}, socket), do: ...
      def handle_info({:show_versions, id}, socket), do: ...
      def handle_info({:expand_row, id}, socket), do: ...
      def handle_info({:row_action, event_name, payload}, socket), do: ...
      def handle_info({:bulk_action, action_name, selected_ids}, socket), do: ...

  ## Row drawer

  A row action of type `:drawer` opens the row in the table's drawer, the UI adapter's `drawer/1`
  or `sheet/1`, which the template draws with `MishkaGervaz.Table.Templates.Shared.render_overlays/1`:
  the row's record view, or the resource's form editing the row (see
  `MishkaGervaz.Table.Types.Action.Drawer`). Its close button closes it. A page
  closes it itself with `close_drawer/2`, as after the form in it saved:

      def handle_info({:form_saved, _mode, record}, socket) do
        MishkaGervaz.Table.Web.Live.close_drawer("posts-table", record)
        {:noreply, socket}
      end

  ## Questions

  A row or bulk action whose `confirm` is a keyword list asks it in the UI adapter's question
  window before it runs, drawn by the table itself (`MishkaGervaz.Question`); a string `confirm`
  stays the browser's own question.

  ## PubSub Integration (Automatic)

  The component automatically subscribes to PubSub topics when `realtime` is configured
  on the resource or domain. It uses `prefix` from the resource's realtime config and
  `pubsub` module from domain defaults.

  The parent LiveView only needs to forward broadcast notifications to the component:

      def handle_info(
            %Phoenix.Socket.Broadcast{topic: "site" <> _, payload: %Ash.Notifier.Notification{} = notification},
            socket
          ) do
        # Get component_id stored by the component during subscription
        if component_id = Process.get({:mishka_gervaz_component, "site"}) do
          send_update(MishkaGervaz.Table.Web.Live,
            id: component_id,
            pubsub_notification: notification
          )
        end
        {:noreply, socket}
      end

  The table reads a burst of notifications once: the first one sends the table a
  `realtime_flush` update, which arrives after the rest of the burst, and one
  `MishkaGervaz.Table.Web.DataLoader.rows_in_view/2` read places every row of it. A burst that
  arrives while the table loads its rows afresh is left to that load.

  ## Expanded Row Content

  When a row is expanded via `:raw_accordion` action, send content back:

      def handle_info({:expand_row, id}, socket) do
        # Load expanded content async
        html = render_expanded_content(id)
        send_update(MishkaGervaz.Table.Web.Live,
          id: "posts-table",
          expanded_html: html
        )
        {:noreply, socket}
      end

  ## Auto Refresh Integration

  When `refresh` is enabled in the DSL, the component schedules a timer that sends
  `:gervaz_refresh` to the parent LiveView. The parent must handle this and forward
  it to the component:

      def handle_info(:gervaz_refresh, socket) do
        # Forward to the table component
        send_update(MishkaGervaz.Table.Web.Live,
          id: "posts-table",
          gervaz_refresh: true
        )
        {:noreply, socket}
      end

  Configure refresh in DSL:

      refresh do
        enabled true
        interval 30_000  # 30 seconds
      end

  See `MishkaGervaz.Table.Web.State`,
  `MishkaGervaz.Table.Web.DataLoader`,
  `MishkaGervaz.Table.Web.Events`,
  `MishkaGervaz.Table.Web.Renderer`,
  `MishkaGervaz.Table.Web.Refresh`,
  `MishkaGervaz.Table.Web.UrlSync`,
  `MishkaGervaz.Resource.Info.Table`.
  """

  use Phoenix.LiveComponent

  alias MishkaGervaz.Table.Web.{State, DataLoader, Events, Renderer, Refresh, UrlSync}
  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Helpers
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.JS

  @doc """
  The JS command that makes the table with this component `id` load its next page, as its Load
  more button does: it pushes `"load_more"` to the table, which streams the page after the last row
  shown, read by keyset when the read action allows it. For a page's own button, such as one in the
  table's `table_footer` slot or chained after the page's own push:

      <button phx-click={MishkaGervaz.Table.Web.Live.load_more("orders-table")}>Load older orders</button>
  """
  @spec load_more(JS.t(), String.t()) :: JS.t()
  def load_more(js \\ %JS{}, id) when is_binary(id),
    do: JS.push(js, "load_more", target: "#" <> id)

  @doc """
  Closes the row drawer of the table with this component `id`. Given the record a form in the
  drawer saved, the table also reads that row again and puts it in its place, as it does for a
  realtime update; a row the table's read no longer finds leaves the list.
  """
  @spec close_drawer(String.t(), Ash.Resource.Record.t() | nil) :: :ok
  def close_drawer(id, saved \\ nil) when is_binary(id),
    do: send_update(__MODULE__, id: id, close_drawer: true, saved: saved)

  @doc """
  Draws the rows of the table with this component `id` in the table's order again, after `moved`
  (a record or a list) changed a field the table sorts by, such as a file moved up or down a list
  ordered by its position. A realtime update leaves a row where it stands, so a page calls this
  for the change instead.

  The table reads as many rows as it shows again from its first page, in its order
  (`MishkaGervaz.Table.Web.DataLoader.rows_in_window/2`), with one row more after them for each
  moved one, and draws them in that order. A moved row that came among them from a later page is
  drawn in its place, and a row shown that now stands just past them stays below them, so the row
  a person moved down past the last one stays in sight. A moved row past them that the view did not
  show is not drawn, and a row shown further on, such as one drawn at the top as it arrived, leaves
  until Load more reads its page. The footer counts the rows drawn.

  The calls of a burst, with the realtime notifications around them, are read together after it, in
  one read; the two rows of a swap heard in two bursts end in the same rows. A table whose read
  cannot answer, such as a manual read, places the moved rows as a realtime update does.

      def handle_info(%Phoenix.Socket.Broadcast{payload: %{action: %{name: :reposition}} = n}, socket) do
        MishkaGervaz.Table.Web.Live.reorder("files-table", n.data)
        {:noreply, socket}
      end
  """
  @spec reorder(String.t(), Ash.Resource.Record.t() | [Ash.Resource.Record.t()]) :: :ok
  def reorder(id, moved) when is_binary(id),
    do: send_update(__MODULE__, id: id, reorder: List.wrap(moved))

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:table_state, nil)
     |> assign(:row_drawer, nil)
     |> assign(:question, nil)
     |> assign(:initialized, false)
     |> assign(:subscribed, false)
     |> assign(:refresh_initialized, false)
     |> assign(:url_sync_pending, false)}
  end

  @impl true
  def update(%{expanded_html: html}, socket) do
    state = socket.assigns.table_state

    if state do
      state = State.update(state, expanded_data: expanded_result(state.expanded_data, html))
      {:ok, socket |> assign(:table_state, state) |> reinsert_expanded_record(state)}
    else
      {:ok, socket}
    end
  end

  def update(%{expanded_error: reason}, socket) do
    state = socket.assigns.table_state

    if state do
      state = State.update(state, expanded_data: expanded_failure(state.expanded_data, reason))
      {:ok, socket |> assign(:table_state, state) |> reinsert_expanded_record(state)}
    else
      {:ok, socket}
    end
  end

  def update(%{pubsub_notification: notification}, socket) do
    socket = handle_pubsub_notification(notification, socket)
    {:ok, socket}
  end

  def update(%{realtime_flush: true}, socket), do: {:ok, flush_realtime(socket)}

  def update(%{reorder: moved}, %{assigns: %{table_state: %State{}}} = socket),
    do: {:ok, place_in_order(socket, moved)}

  def update(%{reorder: _moved}, socket), do: {:ok, socket}

  def update(%{close_drawer: true} = assigns, socket) do
    socket = assign(socket, :row_drawer, nil)

    case {assigns[:saved], socket.assigns.table_state} do
      {%{id: _id} = saved, %State{} = state} -> {:ok, place_row(socket, state, saved)}
      _nothing_saved -> {:ok, socket}
    end
  end

  def update(%{gervaz_refresh: true}, socket) do
    state = socket.assigns.table_state

    if state do
      refresh_config = get_refresh_config(state)

      socket =
        socket
        |> DataLoader.load_async(state, page: 1, reset: true)
        |> Refresh.schedule(refresh_config)

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  def update(assigns, socket) do
    id = Map.fetch!(assigns, :id)
    resource = Map.fetch!(assigns, :resource)
    current_user = Map.get(assigns, :current_user)
    url_state = Map.get(assigns, :url_state)
    existing_state = socket.assigns[:table_state]

    url_sync_pending? = own_url?(socket.assigns[:url_sync_pending], url_state)

    {state, should_load?} =
      cond do
        is_nil(existing_state) ->
          state =
            id
            |> State.init(resource, current_user)
            |> State.apply_view(Map.get(assigns, :view))
            |> State.apply_presentation(assigns)
            |> State.apply_url_state(url_state)
            |> State.hydrate_relation_filter_labels()

          {state, true}

        url_sync_pending? or UrlSync.matches_state?(url_state, existing_state) ->
          path_params = url_state[:path_params] || %{}

          state =
            existing_state
            |> then(fn s ->
              if url_state[:path], do: %{s | base_path: url_state[:path]}, else: s
            end)
            |> then(fn s ->
              if map_size(path_params) > 0, do: %{s | path_params: path_params}, else: s
            end)

          {state, path_params != existing_state.path_params}

        seen_url?(socket.assigns[:url_seen], url_state) ->
          {existing_state, false}

        true ->
          state =
            existing_state
            |> State.apply_url_state(url_state)
            |> State.hydrate_relation_filter_labels()

          {state, true}
      end

    socket =
      socket
      |> assign(:table_state, state)
      |> assign(:resource, resource)
      |> assign(:id, id)
      |> assign(:before_table, Map.get(assigns, :before_table))
      |> assign(:rail, Map.get(assigns, :rail))
      |> assign(:filter_actions, Map.get(assigns, :filter_actions))
      |> assign(:table_footer, Map.get(assigns, :table_footer))
      |> assign(:url_sync_pending, false)
      |> then(fn s ->
        if is_map(url_state[:query]),
          do: assign(s, :url_seen, {url_state.path, url_state.query}),
          else: s
      end)

    socket =
      if not socket.assigns.initialized do
        socket
        |> stream(state.static.stream_name, [])
        |> assign(:initialized, true)
      else
        socket
      end

    socket =
      if connected?(socket) and not socket.assigns.subscribed do
        subscribe_to_pubsub(state, id)
        assign(socket, :subscribed, true)
      else
        socket
      end

    socket =
      cond do
        connected?(socket) and should_load? and state.loading == :initial ->
          DataLoader.load_async(socket, state, page: state.page, reset: true)

        connected?(socket) and should_load? and not is_nil(existing_state) ->
          DataLoader.load_async(socket, state, page: state.page, reset: true)

        true ->
          socket
      end

    socket =
      if connected?(socket) and not socket.assigns.refresh_initialized do
        refresh_config = get_refresh_config(state)

        if refresh_config[:enabled] do
          socket
          |> assign(:refresh_config, refresh_config)
          |> Refresh.init()
          |> assign(:refresh_initialized, true)
        else
          assign(socket, :refresh_initialized, true)
        end
      else
        socket
      end

    {:ok, socket}
  end

  # The URL this table wrote last, coming back: the very one, when the page passes the URL it was
  # given; any, for a page that passes none.
  defp own_url?(url, url_state) when is_binary(url) do
    if is_map(url_state[:query]), do: UrlSync.same_url?(url_state, url), else: true
  end

  defp own_url?(_url, _url_state), do: false

  # The URL the table took last, handed to it again: nothing in it is new. A `url_state` decoded
  # without a URI is never one.
  defp seen_url?({path, query}, %{path: path, query: query}), do: true
  defp seen_url?(_seen, _url_state), do: false

  @spec expanded_result(%AsyncResult{} | nil, term()) :: %AsyncResult{}
  defp expanded_result(%AsyncResult{} = current, html), do: AsyncResult.ok(current, html)
  defp expanded_result(_collapsed, html), do: AsyncResult.ok(html)

  @spec expanded_failure(%AsyncResult{} | nil, term()) :: %AsyncResult{}
  defp expanded_failure(%AsyncResult{} = current, reason), do: AsyncResult.failed(current, reason)

  defp expanded_failure(_collapsed, reason),
    do: AsyncResult.failed(AsyncResult.loading(), reason)

  @impl true
  def handle_event(event, params, socket) do
    Events.handle(event, params, socket)
  end

  @impl true
  def handle_async(name, result, socket) do
    socket = DataLoader.handle_async(name, result, socket)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    Renderer.render(assigns)
  end

  @spec handle_pubsub_notification(Ash.Notifier.Notification.t(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  defp handle_pubsub_notification(notification, socket) do
    state = socket.assigns.table_state

    if state && notification_matches?(notification, state) do
      case run_hook(state.static.hooks, :on_realtime, [notification, socket]) do
        {:halt, socket} ->
          socket

        {:cont, socket} ->
          handle_notification_action(notification, socket.assigns.table_state, socket)

        socket when is_struct(socket, Phoenix.LiveView.Socket) ->
          handle_notification_action(notification, socket.assigns.table_state, socket)

        _ ->
          handle_notification_action(notification, state, socket)
      end
    else
      socket
    end
  end

  @spec run_hook(map() | nil, atom(), list()) :: any()
  defp run_hook(hooks, hook_name, args) when is_map(hooks) do
    case Map.get(hooks, hook_name) do
      func when is_function(func) -> apply(func, args)
      _ -> nil
    end
  end

  defp run_hook(_, _, _), do: nil

  @spec notification_matches?(Ash.Notifier.Notification.t(), State.t()) :: boolean()
  defp notification_matches?(%{resource: resource}, %State{static: %{resource: table_resource}}) do
    resource == table_resource
  end

  @spec handle_notification_action(
          Ash.Notifier.Notification.t(),
          State.t(),
          Phoenix.LiveView.Socket.t()
        ) :: Phoenix.LiveView.Socket.t()
  defp handle_notification_action(%{action: action, data: record}, state, socket) do
    if State.record_visible?(state, record) do
      supports_archive = Info.archive_enabled?(state.static.resource)

      socket
      |> apply_notification_action(action, record, state, supports_archive)
      |> refresh_total_unless_waiting()
    else
      socket
    end
  end

  @spec refresh_total_unless_waiting(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh_total_unless_waiting(socket) do
    if flush_due?(socket), do: socket, else: DataLoader.refresh_total(socket)
  end

  @spec flush_due?(Phoenix.LiveView.Socket.t()) :: boolean()
  defp flush_due?(%{assigns: %{realtime_pending: [_ | _]}}), do: true
  defp flush_due?(%{assigns: %{realtime_moved: [_ | _]}}), do: true
  defp flush_due?(_socket), do: false

  @spec apply_notification_action(
          Phoenix.LiveView.Socket.t(),
          map(),
          map(),
          State.t(),
          boolean()
        ) :: Phoenix.LiveView.Socket.t()
  defp apply_notification_action(socket, action, record, state, supports_archive) do
    case action.type do
      :create ->
        if state.archive_status == :active do
          place_row(socket, state, record)
        else
          socket
        end

      :update ->
        record_archived? = Map.get(record, :archived_at) != nil

        matches_view? =
          (state.archive_status == :active and not record_archived?) or
            (state.archive_status == :archived and record_archived?)

        if matches_view? do
          place_row(socket, state, record)
        else
          delete_row(socket, state, record)
        end

      :destroy ->
        permanent_destroy_action =
          Info.archive_action_for(state.static.resource, :destroy, state.master_user?)

        is_permanent_delete = action.name == permanent_destroy_action

        if supports_archive and not is_permanent_delete do
          if state.archive_status == :archived do
            place_row(socket, state, record)
          else
            delete_row(socket, state, record)
          end
        else
          delete_row(socket, state, record)
        end
    end
  end

  @spec place_row(Phoenix.LiveView.Socket.t(), State.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp place_row(socket, state, record) do
    if connected?(socket),
      do: queue_row(socket, record),
      else: place_rows(socket, state, [record])
  end

  @spec queue_row(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp queue_row(socket, record) do
    pending = socket.assigns[:realtime_pending] || []
    schedule_flush(socket)
    assign(socket, :realtime_pending, [record | Enum.reject(pending, &(&1.id == record.id))])
  end

  @spec place_in_order(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  defp place_in_order(socket, moved) do
    if connected?(socket),
      do: queue_moved(socket, moved),
      else: socket |> reorder_rows(moved) |> DataLoader.refresh_total()
  end

  @spec queue_moved(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  defp queue_moved(socket, moved) do
    ids = MapSet.new(moved, & &1.id)
    earlier = Enum.reject(socket.assigns[:realtime_moved] || [], &MapSet.member?(ids, &1.id))
    schedule_flush(socket)
    assign(socket, :realtime_moved, earlier ++ moved)
  end

  @spec schedule_flush(Phoenix.LiveView.Socket.t()) :: :ok
  defp schedule_flush(socket) do
    case flush_due?(socket) do
      true -> :ok
      false -> send_update(self(), __MODULE__, id: socket.assigns.id, realtime_flush: true)
    end
  end

  @spec flush_realtime(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp flush_realtime(socket) do
    if flush_due?(socket) do
      moved = socket.assigns[:realtime_moved] || []
      moved_ids = MapSet.new(moved, & &1.id)

      pending =
        (socket.assigns[:realtime_pending] || [])
        |> Enum.reject(&MapSet.member?(moved_ids, &1.id))
        |> Enum.reverse()

      socket
      |> assign(:realtime_pending, [])
      |> assign(:realtime_moved, [])
      |> reorder_rows(moved)
      |> place_pending(pending)
      |> DataLoader.refresh_total()
    else
      socket
    end
  end

  @spec place_pending(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  defp place_pending(socket, []), do: socket
  defp place_pending(socket, records), do: place_rows(socket, socket.assigns.table_state, records)

  @spec reorder_rows(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  defp reorder_rows(socket, []), do: socket

  defp reorder_rows(
         %{assigns: %{table_state: %State{loading: :loading, loading_type: :reset}}} = socket,
         _moved
       ),
       do: socket

  defp reorder_rows(socket, moved) do
    state = socket.assigns.table_state

    case DataLoader.rows_in_window(state, length(moved)) do
      {:ok, covered, next} -> draw_in_order(socket, state, covered ++ moved_out(state, next))
      :error -> place_rows(socket, state, moved)
    end
  end

  @spec moved_out(State.t(), list()) :: list()
  defp moved_out(state, next) do
    shown = state.shown_ids || MapSet.new()
    Enum.take_while(next, &MapSet.member?(shown, &1.id))
  end

  @spec draw_in_order(Phoenix.LiveView.Socket.t(), State.t(), list()) ::
          Phoenix.LiveView.Socket.t()
  defp draw_in_order(socket, state, rows) do
    rows = Helpers.inject_preload_aliases(rows, state.preload_aliases)
    drawn = MapSet.new(rows, & &1.id)
    left = MapSet.difference(state.shown_ids || MapSet.new(), drawn)

    new_state =
      state
      |> State.update(shown_ids: drawn, hidden_ids: picks_hidden(state, drawn, left))
      |> keep_drawn(rows)
      |> close_left_expansion(drawn)

    socket
    |> stream(state.static.stream_name, rows, reset: true)
    |> assign(:table_state, new_state)
  end

  @spec picks_hidden(State.t(), MapSet.t(), MapSet.t()) :: MapSet.t()
  defp picks_hidden(%State{selected_ids: selected, hidden_ids: hidden}, drawn, left) do
    Enum.reduce(selected, hidden, &pick_view(&2, &1, drawn, left))
  end

  @spec pick_view(MapSet.t(), term(), MapSet.t(), MapSet.t()) :: MapSet.t()
  defp pick_view(hidden_ids, id, drawn, left) do
    case {MapSet.member?(drawn, id), MapSet.member?(left, id)} do
      {true, _left?} -> hidden(hidden_ids, id, :shown)
      {false, true} -> hidden(hidden_ids, id, :hidden)
      {false, false} -> hidden_ids
    end
  end

  @spec keep_drawn(State.t(), list()) :: State.t()
  defp keep_drawn(%State{static: %{keep_loaded_records: true}} = state, rows),
    do: State.update(state, loaded_records: rows)

  defp keep_drawn(state, _rows), do: state

  @spec close_left_expansion(State.t(), MapSet.t()) :: State.t()
  defp close_left_expansion(%State{expanded_id: nil} = state, _drawn), do: state

  defp close_left_expansion(%State{expanded_id: id} = state, drawn) do
    if MapSet.member?(drawn, id),
      do: state,
      else: State.update(state, expanded_id: nil, expanded_data: nil)
  end

  @spec place_rows(Phoenix.LiveView.Socket.t(), State.t(), [map()]) ::
          Phoenix.LiveView.Socket.t()
  defp place_rows(socket, %State{loading: :loading, loading_type: :reset}, _records), do: socket

  defp place_rows(socket, state, records) do
    case DataLoader.rows_in_view(state, Enum.map(records, & &1.id)) do
      {:ok, rows} ->
        shown = Map.new(rows, &{&1.id, &1})
        Enum.reduce(records, socket, &place_read_row(&2, &1, Map.fetch(shown, &1.id)))

      :error ->
        Enum.reduce(records, socket, &load_and_insert(&2, &2.assigns.table_state, &1))
    end
  end

  @spec place_read_row(Phoenix.LiveView.Socket.t(), map(), {:ok, map()} | :error) ::
          Phoenix.LiveView.Socket.t()
  defp place_read_row(socket, _record, {:ok, row}) do
    socket
    |> insert_row(socket.assigns.table_state, row)
    |> mark_picked(row.id, :shown)
  end

  defp place_read_row(socket, record, :error) do
    socket
    |> leave_view(socket.assigns.table_state, record)
    |> mark_picked(record.id, :hidden)
  end

  @spec mark_picked(Phoenix.LiveView.Socket.t(), term(), :shown | :hidden) ::
          Phoenix.LiveView.Socket.t()
  defp mark_picked(%{assigns: %{table_state: %State{} = state}} = socket, id, view) do
    if MapSet.member?(state.selected_ids, id),
      do: assign(socket, :table_state, %{state | hidden_ids: hidden(state.hidden_ids, id, view)}),
      else: socket
  end

  @spec hidden(MapSet.t(), term(), :shown | :hidden) :: MapSet.t()
  defp hidden(hidden_ids, id, :shown), do: MapSet.delete(hidden_ids, id)
  defp hidden(hidden_ids, id, :hidden), do: MapSet.put(hidden_ids, id)

  @spec leave_view(Phoenix.LiveView.Socket.t(), State.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp leave_view(socket, %State{expanded_id: id} = state, %{id: id} = record) do
    socket
    |> assign(:table_state, State.update(state, expanded_id: nil, expanded_data: nil))
    |> delete_row(state, record)
  end

  defp leave_view(socket, state, record), do: delete_row(socket, state, record)

  @spec load_and_insert(Phoenix.LiveView.Socket.t(), State.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp load_and_insert(socket, state, record) do
    preloads = State.get_preloads(state)
    action = get_action_for_view(state)

    opts = [
      action: action,
      actor: state.current_user,
      load: preloads
    ]

    opts =
      if state.master_user? do
        opts
      else
        Keyword.put(opts, :tenant, Map.get(state.current_user, :site_id))
      end

    case Ash.get(state.static.resource, record.id, opts) do
      {:ok, loaded_record} -> insert_row(socket, state, loaded_record)
      _ -> socket
    end
  end

  @spec insert_row(Phoenix.LiveView.Socket.t(), State.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp insert_row(socket, state, row) do
    row = Helpers.inject_preload_aliases(row, state.preload_aliases)

    socket
    |> Events.show_row(state, row)
    |> keep_row(row)
  end

  @spec delete_row(Phoenix.LiveView.Socket.t(), State.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp delete_row(socket, state, record) do
    socket
    |> stream_delete(state.static.stream_name, record)
    |> assign(
      :table_state,
      Events.drop_shown_row(socket.assigns.table_state, record.id, :realtime)
    )
  end

  @spec keep_row(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp keep_row(
         %{assigns: %{table_state: %State{static: %{keep_loaded_records: true}}}} = socket,
         record
       ) do
    state = socket.assigns.table_state

    rows =
      case Enum.find_index(state.loaded_records, &(&1.id == record.id)) do
        nil -> [record | state.loaded_records]
        index -> List.replace_at(state.loaded_records, index, record)
      end

    assign(socket, :table_state, State.update(state, loaded_records: rows))
  end

  defp keep_row(socket, _record), do: socket

  @spec reinsert_expanded_record(Phoenix.LiveView.Socket.t(), State.t()) ::
          Phoenix.LiveView.Socket.t()
  defp reinsert_expanded_record(socket, %{expanded_id: nil}), do: socket

  defp reinsert_expanded_record(socket, state) do
    opts = [
      action: get_action_for_view(state),
      actor: state.current_user,
      load: State.get_preloads(state)
    ]

    opts =
      if state.master_user? do
        opts
      else
        Keyword.put(opts, :tenant, Map.get(state.current_user, :site_id))
      end

    case Ash.get(state.static.resource, state.expanded_id, opts) do
      {:ok, loaded_record} ->
        loaded_record = Helpers.inject_preload_aliases(loaded_record, state.preload_aliases)
        stream_insert(socket, state.static.stream_name, loaded_record)

      _ ->
        socket
    end
  end

  @spec get_action_for_view(State.t()) :: atom()
  defp get_action_for_view(%{archive_status: :archived} = state) do
    Info.archive_action_for(state.static.resource, :get, state.master_user?) ||
      State.get_action(state, :get)
  end

  defp get_action_for_view(state) do
    State.get_action(state, :get)
  end

  @spec subscribe_to_pubsub(State.t(), String.t()) :: :ok | nil
  defp subscribe_to_pubsub(
         %State{static: %{config: config}, current_user: current_user},
         component_id
       ) do
    realtime = Map.get(config, :realtime, %{})
    enabled = Map.get(realtime, :enabled, false)
    pubsub = Map.get(realtime, :pubsub)
    prefix = Map.get(realtime, :prefix)

    if enabled and not is_nil(pubsub) and not is_nil(prefix) do
      topics = pubsub_topics_for_resource(prefix, current_user)

      for topic <- topics do
        Phoenix.PubSub.subscribe(pubsub, topic)
      end

      Process.put({:mishka_gervaz_component, prefix}, component_id)
    end
  end

  @spec pubsub_topics_for_resource(String.t(), map() | nil) :: list(String.t())
  defp pubsub_topics_for_resource(prefix, current_user) do
    site_id = MishkaGervaz.Helpers.user_tenant(current_user)

    case site_id do
      nil ->
        [
          "#{prefix}:created",
          "#{prefix}:updated",
          "#{prefix}:destroyed"
        ]

      site_id when is_binary(site_id) ->
        [
          "#{prefix}:created",
          "#{prefix}:updated",
          "#{prefix}:destroyed",
          "#{prefix}:#{site_id}:created",
          "#{prefix}:#{site_id}:updated",
          "#{prefix}:#{site_id}:destroyed"
        ]
    end
  end

  @spec get_refresh_config(State.t()) :: map()
  defp get_refresh_config(%State{static: %{config: %{refresh: refresh}}}) when is_map(refresh) do
    %{
      enabled: Map.get(refresh, :enabled, false),
      interval: Map.get(refresh, :interval, 30_000),
      pause_on_interaction: Map.get(refresh, :pause_on_interaction, true),
      show_indicator: Map.get(refresh, :show_indicator, true),
      pause_on_blur: Map.get(refresh, :pause_on_blur, true)
    }
  end

  defp get_refresh_config(_), do: %{enabled: false}
end
