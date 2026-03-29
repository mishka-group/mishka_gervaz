defmodule MishkaGervaz.Form.Web.Live do
  @moduledoc """
  LiveComponent for MishkaGervaz admin forms.

  This is a thin orchestrator that delegates to specialized modules:
  - `State` - State management
  - `DataLoader` - Record loading and relation options
  - `Events` - Event handling
  - `Renderer` - Template rendering

  ## Usage

  Create mode (new record):

      <.live_component
        module={MishkaGervaz.Form.Web.Live}
        id="post-form"
        resource={MyApp.Post}
        current_user={@current_user}
      />

  Edit mode (existing record):

      <.live_component
        module={MishkaGervaz.Form.Web.Live}
        id="post-form"
        resource={MyApp.Post}
        current_user={@current_user}
        record_id={@post_id}
      />

  ## Required Assigns

  - `id` - Unique component ID
  - `resource` - Ash resource module with `MishkaGervaz.Resource` extension
  - `current_user` - Current user for authorization

  ## Optional Assigns

  - `record_id` - ID of record to edit (nil for create mode)
  - `defaults` - Map of default field values for create mode (e.g., `%{workspace_id: @workspace_id}`)

  ## Parent LiveView Integration

  The component sends messages to the parent for certain actions:

      def handle_info({:form_saved, :create, result}, socket), do: ...
      def handle_info({:form_saved, :update, result}, socket), do: ...
      def handle_info({:form_cancelled, resource}, socket), do: ...
      def handle_info({:form_event, event, params}, socket), do: ...
      def handle_info({:add_nested_field, field_name}, socket), do: ...
      def handle_info({:remove_nested_field, field_name, index}, socket), do: ...
  """

  use Phoenix.LiveComponent

  alias MishkaGervaz.Form.Web.{State, DataLoader, Events, Renderer}
  alias MishkaGervaz.Form.Web.UploadHelpers

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:form_state, nil)
     |> assign(:initialized, false)}
  end

  @impl true
  def update(assigns, socket) do
    id = Map.fetch!(assigns, :id)
    resource = Map.get(assigns, :resource) || socket.assigns[:resource]
    current_user = Map.get(assigns, :current_user) || socket.assigns[:current_user]
    record_id = Map.get(assigns, :record_id)
    defaults = Map.get(assigns, :defaults)
    existing_state = socket.assigns[:form_state]

    socket =
      if is_nil(existing_state) do
        state = State.init(id, resource, current_user)
        state = if defaults, do: State.update(state, defaults: defaults), else: state

        socket
        |> assign(:form_state, state)
        |> assign(:resource, resource)
        |> assign(:id, id)
        |> assign(:record_id, record_id)
        |> assign(:initialized, true)
        |> register_uploads(state, id)
        |> maybe_load_form(state, record_id)
      else
        defaults_changed = defaults != existing_state.defaults

        if record_id != socket.assigns[:record_id] or defaults_changed do
          updated_state =
            State.update(existing_state,
              form: nil,
              loading: :initial,
              errors: %{},
              dirty?: false,
              existing_files: %{},
              field_values: %{},
              relation_options: %{},
              defaults: defaults
            )

          socket
          |> assign(:form_state, updated_state)
          |> assign(:record_id, record_id)
          |> maybe_load_form(updated_state, record_id)
        else
          socket
        end
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    events_module(socket.assigns[:form_state]).handle(event, params, socket)
  end

  defp events_module(%{static: %{config: %{events: %{module: mod}}}})
       when not is_nil(mod),
       do: mod

  defp events_module(_), do: Events.Default

  @impl true
  def handle_async(name, result, socket) do
    socket = DataLoader.Default.handle_async_result(name, result, socket)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    Renderer.render(assigns)
  end

  @spec register_uploads(Phoenix.LiveView.Socket.t(), State.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp register_uploads(socket, %{static: %{uploads: uploads}}, id)
       when is_list(uploads) and uploads != [] do
    Enum.reduce(uploads, socket, fn upload_config, acc ->
      name = UploadHelpers.namespaced_upload_name(upload_config.name, id)
      maybe_allow_upload(acc, name, upload_config, id)
    end)
  end

  defp register_uploads(socket, _state, _id), do: socket

  defp maybe_allow_upload(socket, name, upload_config, id) do
    case socket.assigns[:uploads] do
      %{^name => _} ->
        socket

      _ ->
        Phoenix.LiveView.allow_upload(
          socket,
          name,
          UploadHelpers.build_allow_upload_opts(upload_config, id)
        )
    end
  end

  @spec maybe_load_form(
          Phoenix.LiveView.Socket.t(),
          State.t(),
          String.t() | nil
        ) :: Phoenix.LiveView.Socket.t()
  defp maybe_load_form(socket, state, nil) do
    if connected?(socket) do
      if State.Helpers.mode_allowed?(state.static.source, :create, state) do
        DataLoader.new_record(socket, state)
      else
        denied_state = State.update(state, loading: :denied)
        Phoenix.Component.assign(socket, :form_state, denied_state)
      end
    else
      socket
    end
  end

  defp maybe_load_form(socket, state, record_id) do
    if connected?(socket) do
      if State.Helpers.mode_allowed?(state.static.source, :update, state) do
        DataLoader.load_record(socket, state, record_id)
      else
        denied_state = State.update(state, loading: :denied)
        Phoenix.Component.assign(socket, :form_state, denied_state)
      end
    else
      socket
    end
  end
end
