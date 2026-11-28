defmodule MishkaGervaz.Test.Web.CratePageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Form.Web.Live` form of `MishkaGervaz.Test.Web.CrateItem`, mounted
  the way an admin page mounts one. Opened with `?id=<id>`, the form edits that record.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(params, _session, socket), do: {:ok, assign(socket, :record_id, params["id"])}

  @impl true
  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="crate"
      resource={MishkaGervaz.Test.Web.CrateItem}
      current_user={@master}
      record_id={@record_id}
    />
    """
  end
end
