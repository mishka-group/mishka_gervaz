defmodule MishkaGervaz.Test.Web.TablePageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Table.Web.Live` table, mounted the way an admin page mounts one:
  `handle_params/3` decodes the URL into `url_state`, and the table gets it together with an
  activity rail of the page's own. The table is of `MishkaGervaz.Test.Web.FeedItem` on `/feed`, of
  `MishkaGervaz.Test.Web.KeptItem` on `/kept`, of `MishkaGervaz.Test.Web.PlainItem` on `/plain`,
  of `MishkaGervaz.Test.Web.OffsetItem` on `/offset`, and of `MishkaGervaz.Test.Web.GatedItem`
  everywhere else.

  `send(view.pid, :activity)` stands for a live event of the page, such as a PubSub broadcast: it
  redraws the rail, so the page renders the table again with the `url_state` it already holds.
  `send(view.pid, {:notify, notification})` hands an Ash notification on to the table, as a page
  does with the realtime broadcasts it receives.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Table.Web.UrlSync
  alias MishkaGervaz.Test.Web.{FeedItem, GatedItem, KeptItem, OffsetItem, PlainItem}

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
    </.live_component>
    """
  end

  defp resource(:feed), do: FeedItem
  defp resource(:kept), do: KeptItem
  defp resource(:plain), do: PlainItem
  defp resource(:offset), do: OffsetItem
  defp resource(_items), do: GatedItem
end
