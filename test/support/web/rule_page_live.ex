defmodule MishkaGervaz.Test.Web.RulePageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Form.Web.Live` form of `MishkaGervaz.Test.Web.RuleItem`, mounted the
  way an admin page mounts one. A saved record's name shows in `#saved`.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :saved, nil)}

  @impl true
  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.name)}

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="saved">{@saved}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="rule"
      resource={MishkaGervaz.Test.Web.RuleItem}
      current_user={@master}
    />
    """
  end
end
