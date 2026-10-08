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
  - `defaults` - Map of default field values for create mode (e.g., `%{workspace_id: @workspace_id}`).
    A picker's default is saved only while the picker still holds it: once it is cleared, or emptied
    because a field it depends on changed, the save leaves it out.
    An update that leaves the key out, such as the `send_update/2` a table's Edit sends with only a
    `record_id`, keeps the defaults the form has. Pass `defaults: nil` to drop them.
  - `reset` - `true` starts the form over on its `record_id`, even when that is the record already
    open, or `nil` while the form is already on create. See "Opening a form again".

  ## Opening a form again

  A form that stays mounted while it is hidden — in a modal that is shown and hidden, say — keeps
  what was typed, its errors and its pending uploads through a close that sends it nothing, such as
  a modal's close icon. Whatever opens it again starts it over:

      send_update(MishkaGervaz.Form.Web.Live, id: "post-form", record_id: nil, reset: true)

  A create returns to the empty create form, with the form's `defaults`; an edit reads its record
  again. The uploads are cancelled. A create is drawn once without its `<form>` before the empty one
  is built, so every control is drawn anew, a `phx-update="ignore"` one included, and reads the new
  value. A table's Edit sends `reset: true` with the row's `record_id`. A button that opens the form
  without asking the server uses `reset/2`.

  ## After a save

  A create save always returns the form to an empty create form. An update save depends on how the
  form was mounted:

  - mounted with a `record_id` assign (even `nil`) — the form stays on the saved record, reloaded
    for editing. Pass a different `record_id`, or `nil`, to move it.
  - mounted without one, and opened for editing with `send_update/2` — the form returns to an
    empty create form.

  ## Parent LiveView Integration

  The component sends messages to the parent for certain actions:

      def handle_info({:form_saved, :create, result}, socket), do: ...
      def handle_info({:form_saved, :update, result}, socket), do: ...
      def handle_info({:form_cancelled, resource}, socket), do: ...
      def handle_info({:form_event, event, params}, socket), do: ...
      def handle_info({:add_nested_field, field_name}, socket), do: ...
      def handle_info({:remove_nested_field, field_name, index}, socket), do: ...

  See `MishkaGervaz.Form.Web.State` (state shape + override surface),
  `MishkaGervaz.Form.Web.DataLoader` (record + relation loading),
  `MishkaGervaz.Form.Web.Events` (event handling),
  `MishkaGervaz.Form.Web.Renderer` (template dispatch),
  `MishkaGervaz.Form.Web.UploadHelpers`, and
  `MishkaGervaz.Form.Behaviours.Template`.
  """

  use Phoenix.LiveComponent

  alias MishkaGervaz.Form.Web.{State, DataLoader, Events, Renderer}
  alias MishkaGervaz.Form.Web.UploadHelpers
  alias Phoenix.LiveView.JS

  @doc """
  The JS command that starts the form with this component `id` over as an empty create form, as
  `reset: true` with a `nil` `record_id` does. For a button that shows a hidden form on the client:

      <button phx-click={MishkaGervaz.Form.Web.Live.reset("post-form") |> show_modal("post-modal")}>

  It pushes the form's `reset` event to the element with the id `"<id>-form-wrapper"`.
  """
  @spec reset(JS.t(), String.t()) :: JS.t()
  def reset(js \\ %JS{}, id) when is_binary(id),
    do: JS.push(js, "reset", target: "#" <> id <> "-form-wrapper")

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:form_state, nil)
     |> assign(:initialized, false)}
  end

  @impl true
  def update(%{id: _id, build_create: true}, socket) do
    state = socket.assigns[:form_state]

    if state && state.loading == :initial && is_nil(state.form) &&
         is_nil(socket.assigns[:record_id]) do
      {:ok, maybe_load_form(socket, state, nil)}
    else
      {:ok, socket}
    end
  end

  def update(assigns, socket) do
    id = Map.fetch!(assigns, :id)
    resource = Map.get(assigns, :resource) || socket.assigns[:resource]
    current_user = Map.get(assigns, :current_user) || socket.assigns[:current_user]
    record_id = Map.get(assigns, :record_id)
    existing_state = socket.assigns[:form_state]
    defaults = Map.get(assigns, :defaults, existing_state && existing_state.defaults)

    socket =
      if is_nil(existing_state) do
        state = id |> State.init(resource, current_user) |> State.apply_presentation(assigns)
        state = if defaults, do: State.update(state, defaults: defaults), else: state

        socket
        |> assign(:form_state, state)
        |> assign(:resource, resource)
        |> assign(:id, id)
        |> assign(:record_id, record_id)
        |> assign(:record_id_given?, Map.has_key?(assigns, :record_id))
        |> assign(:initialized, true)
        |> register_uploads(state, id)
        |> maybe_load_form(state, record_id)
      else
        defaults_changed = defaults != existing_state.defaults

        cond do
          Map.get(assigns, :reset) == true ->
            socket
            |> assign(:form_state, State.update(existing_state, defaults: defaults))
            |> start_over(record_id)

          record_id != socket.assigns[:record_id] or defaults_changed ->
            updated_state =
              existing_state |> fresh_state() |> State.update(defaults: defaults)

            socket
            |> assign(:form_state, updated_state)
            |> assign(:record_id, record_id)
            |> maybe_load_form(updated_state, record_id)

          true ->
            socket
        end
      end

    {:ok, socket}
  end

  @doc false
  @spec start_over(Phoenix.LiveView.Socket.t(), String.t() | nil) :: Phoenix.LiveView.Socket.t()
  def start_over(socket, record_id) do
    state = socket.assigns.form_state
    socket = Events.cancel_pending_uploads(state, socket)

    fresh_state = fresh_state(state)

    socket =
      socket
      |> assign(:form_state, fresh_state)
      |> assign(:record_id, record_id)

    case record_id do
      nil ->
        send_update(__MODULE__, id: state.static.id, build_create: true)
        socket

      record_id ->
        maybe_load_form(socket, fresh_state, record_id)
    end
  end

  @doc false
  @spec fresh_state(State.t()) :: State.t()
  def fresh_state(%State{} = state) do
    State.update(state,
      form: nil,
      loading: :initial,
      errors: %{},
      form_errors: [],
      dirty?: false,
      existing_files: %{},
      field_values: %{},
      relation_options: static_relation_options(state),
      upload_state: %{}
    )
  end

  defp static_relation_options(%{static: %{fields: fields}, relation_options: options}) do
    names =
      for %{type: :relation, resource: resource} = field <- fields,
          not is_nil(resource),
          (Map.get(field, :mode) || :static) == :static,
          do: field.name

    Map.take(options, names)
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
