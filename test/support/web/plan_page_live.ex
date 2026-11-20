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
    do: {:ok, assign(socket, saved: nil, record_id: params["id"])}

  @impl true
  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.title)}

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="saved">{@saved}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="plan"
      resource={MishkaGervaz.Test.Web.PlanItem}
      current_user={@master}
      record_id={@record_id}
    />
    """
  end
end
