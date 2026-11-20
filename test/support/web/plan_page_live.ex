defmodule MishkaGervaz.Test.Web.PlanPageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Form.Web.Live` form of `MishkaGervaz.Test.Web.PlanItem`, mounted the
  way an admin page mounts one. A saved record's title shows in `#saved`. Opened with `?id=<id>`,
  the form edits that record.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(params, _session, socket),
    do: {:ok, assign(socket, saved: nil, dirty?: false, record_id: params["id"])}

  @impl true
  def handle_info({:put_flash, kind, message}, socket),
    do: {:noreply, put_flash(socket, kind, message)}

  def handle_info({:form_dirty, "plan", dirty?}, socket),
    do: {:noreply, assign(socket, :dirty?, dirty?)}

  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.title)}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="flash-error">{Phoenix.Flash.get(@flash, :error)}</p>
    <p id="saved">{@saved}</p>
    <p id="dirty">{to_string(@dirty?)}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="plan"
      resource={MishkaGervaz.Test.Web.PlanItem}
      current_user={@master}
      record_id={@record_id}
      notify_dirty={true}
    />
    """
  end
end
