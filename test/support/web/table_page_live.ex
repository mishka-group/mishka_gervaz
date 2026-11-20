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

  On `/desk` the table is of `MishkaGervaz.Test.Web.DeskItem`, whose rows open in the table's
  drawer. The drawer's Copy button and its rows' Mark are counted in `#activity`, and a save of the
  form in the drawer
  closes it with `MishkaGervaz.Table.Web.Live.close_drawer/2`, the saved row put back in its place.

  On `/ledger` the table is of `MishkaGervaz.Test.Web.LedgerItem`, read by a master, or with
  `?site=<id>` by that site's admin. Its footer shows the counts, `#more` while rows are left to
  load, and an Older button that loads them with `MishkaGervaz.Table.Web.Live.load_more/2`.

  `send(view.pid, :activity)` stands for a live event of the page, such as a PubSub broadcast: it
  redraws the rail, so the page renders the table again with the `url_state` it already holds.
  `send(view.pid, {:notify, notification})` hands an Ash notification on to the table, as a page
  does with the realtime broadcasts it receives.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Table.Web.UrlSync

  alias MishkaGervaz.Test.Web.{
    DeskItem,
    FeedItem,
    GatedItem,
    KeptItem,
    LedgerItem,
    OffsetItem,
    PlainItem,
    ShelfItem
  }

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign(socket, current_user: user(params), activity: 0, url_state: nil)}
  end

  defp user(%{"site" => site_id}), do: %{id: "admin-1", site_id: site_id, role: :admin}
  defp user(_params), do: @master

  @impl true
  def handle_params(params, uri, socket) do
    resource = resource(socket.assigns.live_action)
    {:noreply, assign(socket, :url_state, UrlSync.decode(params, uri, resource))}
  end

  @impl true
  def handle_event(event, _params, socket) when event in ["add_item", "copy_item"],
    do: {:noreply, update(socket, :activity, &(&1 + 1))}

  @impl true
  def handle_info(:activity, socket), do: {:noreply, update(socket, :activity, &(&1 + 1))}

  def handle_info({:row_action, "mark", _payload}, socket),
    do: {:noreply, update(socket, :activity, &(&1 + 1))}

  def handle_info({:form_saved, _mode, record}, socket) do
    MishkaGervaz.Table.Web.Live.close_drawer("items", record)
    {:noreply, socket}
  end

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
      <:table_footer :let={counts} :if={@live_action in [:shelf, :ledger]}>
        <span id="counts">{counts.shown} of {counts.total}</span>
        <span :if={counts.more?} id="more">more</span>
        <button id="add-item" type="button" phx-click="add_item">Add item</button>
        <button
          :if={@live_action == :ledger}
          id="older"
          type="button"
          phx-click={MishkaGervaz.Table.Web.Live.load_more("items")}
        >
          Older
        </button>
      </:table_footer>
    </.live_component>
    """
  end

  defp resource(:feed), do: FeedItem
  defp resource(:kept), do: KeptItem
  defp resource(:plain), do: PlainItem
  defp resource(:offset), do: OffsetItem
  defp resource(:shelf), do: ShelfItem
  defp resource(:desk), do: DeskItem
  defp resource(:ledger), do: LedgerItem
  defp resource(_items), do: GatedItem
end
