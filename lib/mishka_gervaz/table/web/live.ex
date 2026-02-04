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

  That's it! Everything else comes from the DSL defined on your resource.

  ## Required Assigns

  - `id` - Unique component ID
  - `resource` - Ash resource module with `MishkaGervaz.Resource` extension
  - `current_user` - Current user for authorization

  ## Parent LiveView Integration

  The component sends messages to the parent for certain actions:

      def handle_info({:show_modal, id}, socket), do: ...
      def handle_info({:edit_modal, id}, socket), do: ...
      def handle_info({:show_versions, id}, socket), do: ...
      def handle_info({:expand_row, id}, socket), do: ...
      def handle_info({:row_action, event_name, payload}, socket), do: ...
      def handle_info({:bulk_action, action_name, selected_ids}, socket), do: ...

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
  """

  use Phoenix.LiveComponent

  alias MishkaGervaz.Table.Web.{State, DataLoader, Events, Renderer, Refresh, UrlSync}
  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Helpers
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:table_state, nil)
     |> assign(:initialized, false)
     |> assign(:subscribed, false)
     |> assign(:refresh_initialized, false)}
  end

  @impl true
  def update(%{expanded_html: html}, socket) do
    state = socket.assigns.table_state

    if state do
      state = State.update(state, expanded_data: AsyncResult.ok(state.expanded_data, html))
      socket = assign(socket, :table_state, state) |> reinsert_expanded_record(state)

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  def update(%{expanded_error: reason}, socket) do
    state = socket.assigns.table_state

    if state do
      state =
        State.update(state,
          expanded_data: AsyncResult.failed(state.expanded_data, reason)
        )

      socket = assign(socket, :table_state, state)
      socket = reinsert_expanded_record(socket, state)

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  def update(%{pubsub_notification: notification}, socket) do
    socket = handle_pubsub_notification(notification, socket)
    {:ok, socket}
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

    {state, should_load?} =
      cond do
        is_nil(existing_state) ->
          state =
            id
            |> State.init(resource, current_user)
            |> State.apply_url_state(url_state)
            |> State.hydrate_relation_filter_labels()

          {state, true}

        UrlSync.matches_state?(url_state, existing_state) ->
          state =
            existing_state
            |> then(fn s ->
              if url_state[:path], do: %{s | base_path: url_state[:path]}, else: s
            end)
            |> then(fn s ->
              path_params = url_state[:path_params] || %{}
              if map_size(path_params) > 0, do: %{s | path_params: path_params}, else: s
            end)

          {state, false}

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

      case action.type do
        :create ->
          if state.archive_status == :active do
            reload_and_insert(socket, state, record)
          else
            socket
          end

        :update ->
          record_archived? = Map.get(record, :archived_at) != nil

          matches_view? =
            (state.archive_status == :active and not record_archived?) or
              (state.archive_status == :archived and record_archived?)

          if matches_view? do
            reload_and_insert(socket, state, record)
          else
            stream_delete(socket, state.static.stream_name, record)
          end

        :destroy ->
          permanent_destroy_action =
            Info.archive_action_for(state.static.resource, :destroy, state.master_user?)

          is_permanent_delete = action.name == permanent_destroy_action

          if supports_archive and not is_permanent_delete do
            if state.archive_status == :archived do
              reload_and_insert(socket, state, record)
            else
              stream_delete(socket, state.static.stream_name, record)
            end
          else
            stream_delete(socket, state.static.stream_name, record)
          end
      end
    else
      socket
    end
  end

  @spec reload_and_insert(Phoenix.LiveView.Socket.t(), State.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp reload_and_insert(socket, state, record) do
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
      {:ok, loaded_record} ->
        loaded_record = Helpers.inject_preload_aliases(loaded_record, state.preload_aliases)
        stream_insert(socket, state.static.stream_name, loaded_record, at: 0)

      _ ->
        socket
    end
  end

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
    site_id = if current_user, do: Map.get(current_user, :site_id), else: nil

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
