defmodule MishkaGervaz.Test.Web.TablePageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Table.Web.Live` table, mounted the way an admin page mounts one:
  `handle_params/3` decodes the URL into `url_state`, and the table gets it together with an
  activity rail of the page's own. The table is of `MishkaGervaz.Test.Web.FeedItem` on `/feed`, of
  `MishkaGervaz.Test.Web.KeptItem` on `/kept`, of `MishkaGervaz.Test.Web.PlainItem` on `/plain`,
  of `MishkaGervaz.Test.Web.ShelfItem` on `/shelf`,
  of `MishkaGervaz.Test.Web.OffsetItem` on `/offset`, and of `MishkaGervaz.Test.Web.GatedItem`
  everywhere else.

  On `/shelf` the table's footer shows its counts in `#counts`, beside an Add item button whose
  click the page counts in `#activity`.

  `send(view.pid, :activity)` stands for a live event of the page, such as a PubSub broadcast: it
  redraws the rail, so the page renders the table again with the `url_state` it already holds.
  `send(view.pid, {:notify, notification})` hands an Ash notification on to the table, as a page
  does with the realtime broadcasts it receives.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Table.Web.UrlSync
  alias MishkaGervaz.Test.Web.{FeedItem, GatedItem, KeptItem, OffsetItem, PlainItem, ShelfItem}

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_user: @master, activity: 0, url_state: nil)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    resource = resource(socket.assigns.live_action)
    {:noreply, assign(socket, :url_state, UrlSync.decode(params, uri, resource))}
  end

  @impl true
  def handle_event("add_item", _params, socket),
    do: {:noreply, update(socket, :activity, &(&1 + 1))}

  @impl true
  def handle_info(:activity, socket), do: {:noreply, update(socket, :activity, &(&1 + 1))}

  def handle_info({:notify, notification}, socket) do
    send_update(MishkaGervaz.Table.Web.Live, id: "items", pubsub_notification: notification)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={MishkaGervaz.Table.Web.Live}
      id="items"
      resource={resource(@live_action)}
      current_user={@current_user}
      url_state={@url_state}
      url_sync={@live_action != :keeps_url}
    >
      <:rail>
        <p id="activity">{@activity}</p>
      </:rail>
      <:table_footer :let={counts} :if={@live_action == :shelf}>
        <span id="counts">{counts.shown} of {counts.total}</span>
        <button id="add-item" type="button" phx-click="add_item">Add item</button>
      </:table_footer>
    </.live_component>
    """
  end

  defp resource(:feed), do: FeedItem
  defp resource(:kept), do: KeptItem
  defp resource(:plain), do: PlainItem
  defp resource(:offset), do: OffsetItem
  defp resource(:shelf), do: ShelfItem
  defp resource(_items), do: GatedItem
end
