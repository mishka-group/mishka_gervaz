defmodule MishkaGervaz.Test.Web.StepPageLive do
  @moduledoc """
  A page with the wizard of `MishkaGervaz.Test.Web.StepItem`, mounted with `record_id`, `step` and
  `notify_step`, as a page that keeps the record and the step in its URL. Opened with `?id=<id>`
  the form edits that record, with `?step=<name>` it opens on that step.

  Each save the form sends shows in `#saved` as `<mode>:<title>`, and the page keeps the saved
  record's id as the form's `record_id`. The step the form tells the page it moved to shows in
  `#step`. The page adds `#content-extra`, reading the form's mode, to the `:content` step through
  the form's `:in_step` slot.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(params, _session, socket) do
    new_socket =
      assign(socket, saved: [], record_id: params["id"], step: params["step"], told: nil)

    {:ok, new_socket}
  end

  @impl true
  def handle_info({:put_flash, kind, message}, socket),
    do: {:noreply, put_flash(socket, kind, message)}

  def handle_info({:form_saved, mode, record}, socket) do
    new_socket =
      socket
      |> update(:saved, &(&1 ++ ["#{mode}:#{record.title}"]))
      |> assign(:record_id, record.id)

    {:noreply, new_socket}
  end

  def handle_info({:form_step, "steps", step}, socket),
    do: {:noreply, assign(socket, step: step, told: step)}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="saved">{Enum.join(@saved, ",")}</p>
    <p id="step">{@told}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="steps"
      resource={MishkaGervaz.Test.Web.StepItem}
      current_user={@master}
      record_id={@record_id}
      step={@step}
      notify_step={true}
    >
      <:in_step :let={form} name={:content}>
        <p id="content-extra">Editing as {form.state.mode}</p>
      </:in_step>
    </.live_component>
    """
  end
end
