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
    New defaults start a create form over only while it holds no changes and a field's own default
    is among what changed. Otherwise the form keeps what was typed, its errors and the step it is
    on, and its notices and options read the new values, so a page may pass live data (a product's
    name, a count of buyers) and refresh it while the form is open.
  - `reset` - `true` starts the form over on its `record_id`, even when that is the record already
    open, or `nil` while the form is already on create. See "Opening a form again".
  - `body` - a slot that places the form's groups in the page's own markup. See "Placing the
    groups in the page".
  - `in_step` - a slot, one entry per step, that adds the page's own markup to a step of a wizard
    or tabs form. See "The page's markup in a step".
  - `notify_dirty` - `true` sends the page `{:form_dirty, id, dirty?}` each time the form comes to
    hold changes the reader has not saved, and each time it holds none any more: after a save, a
    Discard, a Cancel or a start over. See "Unsaved changes".
  - `notify_failed` - `true` sends the page `{:form_failed, id, failure}` each time a save is
    refused. See "After a refused save".
  - `navigation` - `:sequential` or `:free`, in place of the `navigation` the resource's `layout`
    declares. See "Steps the page chooses".
  - `step` - the step a wizard or tabs form opens on. See "Steps the page chooses".
  - `notify_step` - `true` sends the page `{:form_step, id, step}` each time a wizard or tabs form
    moves to another step. See "Steps the page chooses".

  ## Placing the groups in the page

  A page that draws a form's groups in its own cards or steps, with other markup between them,
  passes a `:body` slot. The slot is given the form, and `group/1` draws one named group of it
  wherever the page calls it:

      <.live_component
        module={MishkaGervaz.Form.Web.Live}
        id="post-form"
        resource={MyApp.Post}
        current_user={@current_user}
      >
        <:body :let={form}>
          <section class="card">
            <h2>Basics</h2>
            <MishkaGervaz.Form.Web.Live.group form={form} name={:basics} />
          </section>
          <section class="card">The page's own content, not part of the form.</section>
          <section class="card">
            <h2>Publishing</h2>
            <MishkaGervaz.Form.Web.Live.group form={form} name={:publishing} />
          </section>
        </:body>
      </.live_component>

  It stays one form: everything in the slot is inside the one `<form>`, so one changeset is
  validated and saved, a field's error shows in the group that holds it, and the unsaved changes,
  Discard and the submit row work as they do without the slot. The page's own markup in the slot is
  inside that `<form>` too, so it holds no `<form>` of its own and no input with a `name` that is
  not the form's. Events of the page's markup go to the page, as anywhere else, unless they name a
  `phx-target`.

  The slot is used by a `:standard` form (`MishkaGervaz.Form.Templates.Standard`, "Placed groups").
  A group the page does not place is not drawn; a field in no group is drawn after the slot.

  ## The page's markup in a step

  A page that adds its own markup to a step of a `:wizard` or `:tabs` form, a list of the record's
  files say, passes an `:in_step` slot naming the step. The entry is drawn in that step's panel
  after the step's groups, so it shows with its step and hides with it, and is given the form as
  the `:body` slot is:

      <.live_component
        module={MishkaGervaz.Form.Web.Live}
        id="post-form"
        resource={MyApp.Post}
        current_user={@current_user}
        record_id={@post_id}
      >
        <:in_step :let={form} name={:content}>
          <.attachments :if={form.state.mode == :update} post_id={@post_id} />
        </:in_step>
      </.live_component>

  Several entries may name one step; they are drawn in their order. It stays one form: the markup
  is inside the one `<form>`, so it holds no `<form>` of its own and no input with a `name` that is
  not the form's, and its events go to the page unless they name a `phx-target`. A step the form
  has no step for raises an `ArgumentError`; a `:standard` form ignores the slot.

  ## Steps the page chooses

  A page decides three things about the steps of a `:wizard` or `:tabs` form when it mounts it.

  `navigation` takes the place of the resource's own, so one resource is drawn as steps that open
  in order (`:sequential`: Back and Next, Save on the last step) while a record is made, and as
  free tabs (`:free`: Save on every tab) once it exists. `:free` on a `:wizard`, or any other value,
  raises an `ArgumentError`. A later render that passes another value switches the form over.

  `step` opens the form on that step, an atom or its string as a URL carries it. In a wizard, or
  tabs whose steps open in order, the steps before it count as done, so Back and their tabs reach
  them. A name the form has no step for leaves it on its first step. The form moves when `step`
  changes from what the page passed before, and when the form starts over, on another `record_id`
  or a `reset`; a render that passes the same value again leaves the form where the reader took it.

  `notify_step={true}` tells the page each step the form moves to, by Next, Back, a tab, a save that
  failed on another step or a start over, as `{:form_step, id, step}`. A page that keeps the step in
  its URL hands it back as `step`, which leaves the form where it is:

      <.live_component
        module={MishkaGervaz.Form.Web.Live}
        id="post-form"
        resource={MyApp.Post}
        current_user={@current_user}
        record_id={@post_id}
        navigation={if @post_id, do: :free, else: :sequential}
        step={@step}
        notify_step={true}
      />

      def handle_info({:form_step, "post-form", step}, socket),
        do: {:noreply, push_patch(socket, to: ~p"/posts/\#{socket.assigns.post_id}?step=\#{step}")}

  ## Unsaved changes

  The form's wrapper, `"<id>-form-wrapper"`, carries `data-dirty="true"` while the form holds
  changes. A page that wants to know, to ask before it closes the form's window, mounts the form
  with `notify_dirty={true}` and keeps what it is told:

      def handle_info({:form_dirty, "post-form", dirty?}, socket),
        do: {:noreply, assign(socket, :post_form_dirty?, dirty?)}

  A `cancel` or `discard` button of the form's `submit` block with a `confirm` asks it before it
  acts while the form holds changes. A form in the UI adapter's `drawer/1` or `sheet/1` passes
  `confirm_close={@post_form_dirty? && "Discard your changes?"}`, so closing the window asks too.

  ## Asking before a save

  A `create` or `update` button of the form's `submit` block whose `confirm` is a keyword list asks
  it in the UI adapter's question window before the save runs, drawn by the form itself under its
  `<form>` with the id `"<id>-question"` (`MishkaGervaz.Question`). The save runs with the values the
  form was submitted with once the question is answered; Cancel saves nothing.

      submit do
        update confirm: [
                 title: "Publish the changes?",
                 body: fn product -> "Buyers of \#{product.name} see them at once." end,
                 tone: :warn,
                 confirm_label: "Publish"
               ]
      end

  ## Opening a form again

  A form that stays mounted while it is hidden — in a modal that is shown and hidden, say — keeps
  what was typed, its errors and its pending uploads through a close that sends it nothing, such as
  a modal's close icon. Whatever opens it again starts it over:

      send_update(MishkaGervaz.Form.Web.Live, id: "post-form", record_id: nil, reset: true)

  A create returns to the empty create form, with the form's `defaults`; an edit reads its record
  again. The uploads are cancelled. A create is drawn once without its `<form>` before the empty one
  is built, so every control is drawn anew, a `phx-update="ignore"` one included, and reads the new
  value. A table's Edit sends `reset: true` with the row's `record_id`. A button that opens the form
  without asking the server uses `reset/2`. In a drawer, a sheet or a window the new `<form>` takes
  the focus the panel gave the old one as it opened (see `MishkaGervaz.Form.Templates.Standard`,
  "In a drawer, a sheet or a window").

  A record read again, the one the form is on, after an update save, a Discard or a `reset: true`
  with its `record_id`, keeps the form it was drawn with until the record arrives, and the fresh
  form takes its place then. So the steps, the step the form is on and the page's `:in_step`
  entries stay on the page, and a live component in an entry keeps what it holds, the rows of a
  table's stream say. A save, a Next or an answered question sent while the record is read again
  does nothing. Another record is drawn anew, after the form's loading state.

  ## Values the page works out

  A page that works a value out while the form is open, such as the date a price preview was made
  for, puts it into the mounted form without starting it over:

      MishkaGervaz.Form.Web.Live.put_values("plan-form", %{proration_date: preview.date})

  It is `send_update(MishkaGervaz.Form.Web.Live, id: "plan-form", put_values: %{...})`. Each key
  names a field of the form, as an atom or a string; a name the form has no field for raises an
  `ArgumentError`. The form is validated with the values in it, as a change typed into it is (its
  `on_validate` hook runs, and the errors show as they would), and the save sends them, a `:hidden`
  field's included. What the reader typed into the other fields stays, and the form's dirty state
  and step stay as they were: a value the page put is not a change the reader made. A field the
  reader may not change shows the value, and the save leaves it out, as it leaves out anything typed
  into such a field.

  Values put while the form is still reading its record, or being built again after a start over,
  are put once it is ready. An update that carries `put_values` does nothing else.

  ## After a save

  A create save returns the form to an empty create form, on its first step. An update save depends
  on how the form was mounted:

  - mounted with a `record_id` assign (even `nil`) — the form stays on the saved record, reloaded
    for editing, on the step or tab it is on. Pass a different `record_id`, or `nil`, to move it.
  - mounted without one, and opened for editing with `send_update/2` — the form returns to an
    empty create form.

  Next on a wizard step that says `save true` (`MishkaGervaz.Form.Entities.Step`, "A step that
  saves") saves too, a create first and an update after, and the form stays on the saved record,
  reloaded for editing, on the next step. A page that passes `record_id` keeps the record's id from
  the `{:form_saved, :create, record}` it is sent, so its next render passes the same record:

      def handle_info({:form_saved, :create, post}, socket),
        do: {:noreply, assign(socket, :post_id, post.id)}

  ## After a refused save

  A save the form refuses, for the action's errors, a field type's or a `before_save` that halted,
  keeps what was typed, shows each message under its field, and moves the reader to the first field
  with an error, in the order the form draws them: the field is focused, which scrolls it into
  view, and a collapsed group or another step holding it is opened first. A refusal no field shows
  moves the reader to the message above the submit row. It is done with `Phoenix.LiveView.JS` in the
  template, so the page needs no hook.

  A page that wants to say it too, in a toast, mounts the form with `notify_failed={true}`:

      def handle_info({:form_failed, "post-form", %{fields: fields}}, socket) do
        new_socket = MishkaGervaz.Toast.push(socket, :error, "Check the \#{length(fields)} marked fields.")
        {:noreply, new_socket}
      end

  `failure` is a map: `:mode`, `:create` or `:update`; `:fields`, the names of the fields showing an
  error, in the order the form declares them; and `:messages`, the messages shown above the submit
  row, which no field shows.

  ## Parent LiveView Integration

  The component sends messages to the parent for certain actions:

      def handle_info({:form_saved, :create, result}, socket), do: ...
      def handle_info({:form_saved, :update, result}, socket), do: ...
      def handle_info({:form_cancelled, resource}, socket), do: ...
      def handle_info({:form_event, event, params}, socket), do: ...
      def handle_info({:add_nested_field, field_name}, socket), do: ...
      def handle_info({:remove_nested_field, field_name, index}, socket), do: ...
      def handle_info({:put_flash, kind, message}, socket), do: ...

  A wizard or tabs form whose save failed on a field of an earlier step sends `{:put_flash, :error,
  message}`, naming the step to check (see `MishkaGervaz.Form.Web.Events.StepHandler`); the page
  puts it with `Phoenix.LiveView.put_flash/3`.

  See `MishkaGervaz.Form.Web.State` (state shape + override surface),
  `MishkaGervaz.Form.Web.DataLoader` (record + relation loading),
  `MishkaGervaz.Form.Web.Events` (event handling),
  `MishkaGervaz.Form.Web.Renderer` (template dispatch),
  `MishkaGervaz.Form.Web.UploadHelpers`, and
  `MishkaGervaz.Form.Behaviours.Template`.
  """

  use Phoenix.LiveComponent

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Form.Web.{State, DataLoader, Events, Renderer}
  alias MishkaGervaz.Form.Web.Events.{RelationHandler, StepHandler}
  alias MishkaGervaz.Form.Web.UploadHelpers
  alias MishkaGervaz.Helpers
  alias MishkaGervaz.Resource.Info.Form, as: Info
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

  @doc """
  Puts `values` (`%{field => value}`) into the mounted form with this component `id`, keeping what
  was typed. See "Values the page works out".
  """
  @spec put_values(String.t(), map()) :: :ok
  def put_values(id, values) when is_binary(id) and is_map(values),
    do: send_update(__MODULE__, id: id, put_values: values)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:form_state, nil)
     |> assign(:question, nil)
     |> assign(:pending_values, nil)
     |> assign(:step_given, nil)
     |> assign(:initialized, false)}
  end

  @impl true
  def update(assigns, socket) do
    was_dirty? = dirty?(socket)
    was_step = current_step(socket)
    {:ok, updated_socket} = do_update(assigns, keep_body(socket, assigns))

    new_socket =
      updated_socket
      |> announce_dirty(was_dirty?)
      |> announce_step(was_step)
      |> count_step_move(was_step)

    {:ok, new_socket}
  end

  # The page's `:body` and `:in_step` slots come with every render of the page; a `send_update/2`
  # without them keeps the ones the form has.
  defp keep_body(socket, assigns) do
    Enum.reduce([:body, :in_step], socket, fn slot, acc ->
      case assigns do
        %{^slot => entries} -> assign(acc, slot, entries)
        _no_slot -> assign_new(acc, slot, fn -> [] end)
      end
    end)
  end

  attr :form, :map,
    required: true,
    doc: "the form as the `:body` slot gives it (`<:body :let={form}>`)"

  attr :name, :atom, required: true, doc: "the name of a group of the form's `groups` section"

  @doc """
  Draws one group of a form inside the form's `:body` slot, with the notices placed before and
  after it, through the form's template (`render_group/1`). See "Placing the groups in the page".

  While the form loads the group draws the template's loading state; a group the reader may not see
  (its `visible` or `restricted`), or a form the reader may not use, draws nothing. A name the form
  has no group for raises an `ArgumentError`.
  """
  @spec group(map()) :: Phoenix.LiveView.Rendered.t()
  def group(%{form: %{static: static, state: state} = form, name: name} = assigns) do
    template = static.template || Standard

    group =
      Enum.find(static.groups, &(&1.name == name)) ||
        raise ArgumentError,
              "the form #{inspect(static.id)} has no group #{inspect(name)}, it has " <>
                inspect(Enum.map(static.groups, & &1.name))

    drawn = Map.put(form, :group, group)

    assigns =
      assigns
      |> assign(:drawn, drawn)
      |> assign(:template, template)
      |> assign(:show, group_state(state, group))

    ~H"""
    <%= case @show do %>
      <% :loading -> %>
        {@template.render_loading(@drawn)}
      <% :shown -> %>
        {Standard.render_notices_at(@drawn, {:before_group, @name})}
        {@template.render_group(@drawn)}
        {Standard.render_notices_at(@drawn, {:after_group, @name})}
      <% :hidden -> %>
    <% end %>
    """
  end

  defp group_state(%{loading: :denied}, _group), do: :hidden

  defp group_state(%{loading: loading, form: form} = state, group)
       when loading in [:loaded, :loading] and not is_nil(form),
       do: (Helpers.accessible?(group, state) && :shown) || :hidden

  defp group_state(_state, _group), do: :loading

  defp do_update(%{id: _id, build_create: true}, socket) do
    state = socket.assigns[:form_state]

    if state && state.loading == :initial && is_nil(state.form) &&
         is_nil(socket.assigns[:record_id]) do
      {:ok, socket |> maybe_load_form(state, nil) |> put_pending_values()}
    else
      {:ok, socket}
    end
  end

  defp do_update(%{id: _id, put_values: values}, socket) when is_map(values),
    do: {:ok, put_form_values(socket, values)}

  defp do_update(assigns, socket) do
    id = Map.fetch!(assigns, :id)
    resource = Map.get(assigns, :resource) || socket.assigns[:resource]
    current_user = Map.get(assigns, :current_user) || socket.assigns[:current_user]
    record_id = Map.get(assigns, :record_id)
    existing_state = socket.assigns[:form_state]
    defaults = Map.get(assigns, :defaults, existing_state && existing_state.defaults)
    opened = existing_state && existing_state.opened

    socket =
      if is_nil(existing_state) do
        state = id |> State.init(resource, current_user) |> State.apply_presentation(assigns)
        state = if defaults, do: State.update(state, defaults: defaults), else: state

        socket
        |> assign(:form_state, state)
        |> assign(:resource, resource)
        |> assign(:id, id)
        |> assign(:notify_dirty, Map.get(assigns, :notify_dirty) == true)
        |> assign(:notify_failed, Map.get(assigns, :notify_failed) == true)
        |> assign(:notify_step, Map.get(assigns, :notify_step) == true)
        |> assign(:record_id, record_id)
        |> assign(:record_id_given?, Map.has_key?(assigns, :record_id))
        |> assign(:initialized, true)
        |> register_uploads(state, id)
        |> maybe_load_form(state, record_id)
      else
        cond do
          Map.get(assigns, :reset) == true ->
            socket
            |> assign(:form_state, State.update(existing_state, defaults: defaults))
            |> start_over(record_id)
            |> open_step(Map.get(assigns, :open_step))

          record_id != socket.assigns[:record_id] or
              follows_defaults?(existing_state, defaults) ->
            updated_state =
              existing_state |> fresh_state() |> State.update(defaults: defaults)

            socket
            |> assign(:form_state, updated_state)
            |> assign(:record_id, record_id)
            |> maybe_load_form(updated_state, record_id)

          defaults != existing_state.defaults ->
            assign(socket, :form_state, State.update(existing_state, defaults: defaults))

          true ->
            socket
        end
      end

    new_socket =
      socket
      |> put_navigation(assigns)
      |> follow_step(assigns, socket.assigns.form_state.opened != opened)

    {:ok, new_socket}
  end

  # The step a save that kept its record open starts over on, see
  # `MishkaGervaz.Form.Web.Events.SubmitHandler.reopening/3`.
  defp open_step(socket, nil), do: socket

  defp open_step(socket, step),
    do: Phoenix.Component.update(socket, :form_state, &StepHandler.opened(&1, step))

  defp put_navigation(%{assigns: %{form_state: state}} = socket, %{navigation: navigation})
       when not is_nil(navigation) and navigation != state.static.layout_navigation,
       do: assign(socket, :form_state, State.apply_presentation(state, %{navigation: navigation}))

  defp put_navigation(socket, _assigns), do: socket

  # The `step` the page passes opens the form on it when it differs from the one it passed before,
  # and when the form started over; a render that passes the same one again leaves the step the
  # reader took.
  defp follow_step(%{assigns: %{form_state: state}} = socket, %{step: given}, restarted?) do
    name = StepHandler.step_name(state, given)

    opened_socket =
      if (restarted? or name != socket.assigns.step_given) and
           name not in [nil, state.current_step],
         do: assign(socket, :form_state, StepHandler.opened(state, name)),
         else: socket

    assign(opened_socket, :step_given, name)
  end

  defp follow_step(socket, _assigns, _restarted?), do: socket

  # A create form with no changes is built again when a field's default changed, so its inputs
  # draw the new value. A form with changes, an edit, or defaults no field reads keep the form.
  defp follows_defaults?(%State{defaults: defaults}, defaults), do: false
  defp follows_defaults?(%State{dirty?: true}, _defaults), do: false
  defp follows_defaults?(%State{mode: :update}, _defaults), do: false

  defp follows_defaults?(%State{defaults: old, static: %{fields: fields}}, new) do
    Enum.any?(fields, &(field_default(old, &1.name) != field_default(new, &1.name)))
  end

  defp field_default(defaults, name) when is_map(defaults) do
    case defaults do
      %{^name => value} -> value
      _not_by_atom -> Map.get(defaults, to_string(name))
    end
  end

  defp field_default(_defaults, _name), do: nil

  @doc false
  @spec start_over(Phoenix.LiveView.Socket.t(), String.t() | nil) :: Phoenix.LiveView.Socket.t()
  def start_over(socket, record_id) do
    state = socket.assigns.form_state
    socket = Events.cancel_pending_uploads(state, socket)

    fresh_state =
      state
      |> fresh_state()
      |> keep_drawn(state, record_id, socket.assigns[:record_id])

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

  # A record read again keeps the form it was drawn with until it arrives, so its steps, the page's
  # `:in_step` entries and a live component in them stay on the page. Another record, or a create,
  # is drawn anew.
  defp keep_drawn(fresh, %State{form: form, loading: :loaded} = drawn, record_id, record_id)
       when not is_nil(form) and not is_nil(record_id) do
    State.update(fresh,
      form: form,
      field_values: drawn.field_values,
      relation_options: drawn.relation_options,
      existing_files: drawn.existing_files
    )
  end

  defp keep_drawn(fresh, _drawn, _record_id, _open_record_id), do: fresh

  @doc """
  Puts the form back to its starting values, as the `discard` button of the form's `submit` block
  does: an edit reads its record again, a create starts over empty, with the form's `defaults`.
  The pending uploads are cancelled. A `:tabs` form stays on the tab it is on.
  """
  @spec discard(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def discard(socket) do
    state = socket.assigns.form_state
    record_id = if state.mode == :update, do: socket.assigns[:record_id]
    step = if state.static.layout_mode == :tabs, do: state.current_step
    reopen(socket, record_id, step)
  end

  @doc false
  @spec reopen(Phoenix.LiveView.Socket.t(), String.t() | nil, atom() | nil) ::
          Phoenix.LiveView.Socket.t()
  def reopen(socket, record_id, step) do
    socket
    |> start_over(record_id)
    |> open_step(step)
  end

  @doc false
  @spec fresh_state(State.t()) :: State.t()
  def fresh_state(%State{} = state) do
    State.update(
      state,
      [
        form: nil,
        loading: :initial,
        errors: %{},
        form_errors: [],
        dirty?: false,
        existing_files: %{},
        field_values: %{},
        relation_options: static_relation_options(state),
        upload_state: %{},
        empty_files: %{},
        pickers: %{},
        opened: (state.opened || 0) + 1
      ] ++ first_step(state)
    )
  end

  # A wizard or tabs form starts over on its first step, as the resource's step builder names it.
  defp first_step(%{static: %{layout_mode: mode, steps: steps, resource: resource}})
       when mode in [:wizard, :tabs] do
    builder = Map.get(Info.state(resource), :step, State.StepBuilder.Default)
    current = builder.initial_step(steps)

    [
      current_step: current,
      step_states: builder.initial_step_states(steps),
      wizard_history: List.wrap(current)
    ]
  end

  defp first_step(_state), do: []

  defp static_relation_options(%{static: %{fields: fields}, relation_options: options}) do
    names =
      for %{type: :relation, resource: resource} = field <- fields,
          not is_nil(resource),
          (Map.get(field, :mode) || :static) == :static,
          do: field.name

    Map.take(options, names)
  end

  @impl true
  def handle_event(event, _params, %{assigns: %{form_state: %State{loading: :loading}}} = socket)
      when event in ["save", "next_step", "question_confirm"],
      do: {:noreply, socket}

  def handle_event(event, params, socket) do
    {:noreply, handled_socket} =
      events_module(socket.assigns[:form_state]).handle(event, params, socket)

    new_socket =
      handled_socket
      |> announce_dirty(dirty?(socket))
      |> announce_failed(failed_saves(socket))
      |> announce_step(current_step(socket))
      |> count_step_move(current_step(socket))

    {:noreply, new_socket}
  end

  defp events_module(%{static: %{config: %{events: %{module: mod}}}})
       when not is_nil(mod),
       do: mod

  defp events_module(_), do: Events.Default

  @impl true
  def handle_async(name, result, socket) do
    new_socket =
      name
      |> DataLoader.Default.handle_async_result(result, socket)
      |> put_pending_values()

    announced_socket =
      new_socket
      |> announce_dirty(dirty?(socket))
      |> announce_step(current_step(socket))
      |> count_step_move(current_step(socket))

    {:noreply, announced_socket}
  end

  # The values a page put (`put_values/2`): into the form once it is built, validated with them as
  # a typed change is, its dirty state and step untouched; kept until then.
  defp put_form_values(%{assigns: %{form_state: state}} = socket, values) do
    values = form_values!(state, values)

    case state do
      %State{form: %Phoenix.HTML.Form{}, loading: :loaded} ->
        new_state =
          state
          |> State.update(field_values: Map.merge(state.field_values || %{}, values))
          |> RelationHandler.revalidate_form(values)

        assign(socket, :form_state, new_state)

      _not_built ->
        assign(socket, :pending_values, Map.merge(socket.assigns[:pending_values] || %{}, values))
    end
  end

  defp put_pending_values(
         %{assigns: %{pending_values: values, form_state: %State{form: form, loading: :loaded}}} =
           socket
       )
       when is_map(values) and not is_nil(form) do
    socket
    |> assign(:pending_values, nil)
    |> put_form_values(values)
  end

  defp put_pending_values(socket), do: socket

  defp form_values!(%State{static: %{fields: fields, id: id}}, values) do
    names = Map.new(fields, &{Atom.to_string(&1.name), &1.name})

    Map.new(values, fn {key, value} ->
      case Map.fetch(names, to_string(key)) do
        {:ok, name} ->
          {name, value}

        :error ->
          raise ArgumentError,
                "the form #{inspect(id)} has no field #{inspect(key)}, it has " <>
                  inspect(Map.values(names))
      end
    end)
  end

  defp dirty?(%{assigns: %{form_state: %State{dirty?: dirty?}}}), do: dirty? == true
  defp dirty?(_socket), do: false

  # A form mounted with `notify_dirty` tells its page each time it comes to hold changes, or holds
  # none any more.
  defp announce_dirty(%{assigns: %{notify_dirty: true}} = socket, was_dirty?) do
    case dirty?(socket) do
      ^was_dirty? ->
        socket

      dirty? ->
        send(self(), {:form_dirty, socket.assigns.id, dirty?})
        socket
    end
  end

  defp announce_dirty(socket, _was_dirty?), do: socket

  defp current_step(%{assigns: %{form_state: %State{current_step: step}}}), do: step
  defp current_step(_socket), do: :unmounted

  # Each move to another step after the form is mounted is counted, so the template draws a new
  # mark that focuses the first field of the step moved to.
  defp count_step_move(socket, :unmounted), do: socket

  defp count_step_move(socket, was) do
    case socket.assigns.form_state do
      %State{current_step: ^was} ->
        socket

      %State{current_step: nil} ->
        socket

      %State{step_moves: moves} = state ->
        assign(socket, :form_state, State.update(state, step_moves: moves + 1))
    end
  end

  # A form mounted with `notify_step` tells its page each step it moves to; the step it is mounted
  # on the page already knows.
  defp announce_step(%{assigns: %{notify_step: true}} = socket, was)
       when was != :unmounted do
    case current_step(socket) do
      ^was ->
        socket

      step ->
        send(self(), {:form_step, socket.assigns.id, step})
        socket
    end
  end

  defp announce_step(socket, _was), do: socket

  defp failed_saves(%{assigns: %{form_state: %State{failed_saves: count}}}), do: count
  defp failed_saves(_socket), do: 0

  # A form mounted with `notify_failed` tells its page each time a save is refused.
  defp announce_failed(
         %{assigns: %{notify_failed: true, form_state: %State{failed_saves: count} = state}} =
           socket,
         before
       )
       when count != before do
    errors = state.errors || %{}

    failure = %{
      mode: state.mode,
      fields: for(%{name: name} <- state.static.fields, failed?(errors, name), do: name),
      messages: state.form_errors || []
    }

    send(self(), {:form_failed, socket.assigns.id, failure})
    socket
  end

  defp announce_failed(socket, _before), do: socket

  defp failed?(errors, name), do: Map.get(errors, name) not in [nil, [], ""]

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
