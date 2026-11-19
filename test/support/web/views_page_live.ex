defmodule MishkaGervaz.Test.Web.ViewsPageLive do
  @moduledoc """
  A page with two tables of `MishkaGervaz.Test.Resources.ViewedOrder`: `#orders` draws the table
  itself, and `#refunds` its `:refunds` view.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Test.Resources.ViewedOrder

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :current_user, @master)}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={MishkaGervaz.Table.Web.Live}
      id="orders"
      resource={ViewedOrder}
      current_user={@current_user}
    />
    <.live_component
      module={MishkaGervaz.Table.Web.Live}
      id="refunds"
      resource={ViewedOrder}
      view={:refunds}
      current_user={@current_user}
    />
    """
  end
end
