defmodule MishkaGervaz.Test.Web.TablePageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Table.Web.Live` table of `MishkaGervaz.Test.Web.GatedItem`, mounted
  the way an admin page mounts one: `handle_params/3` decodes the URL into `url_state`, and the
  table gets it together with an activity rail of the page's own.

  `send(view.pid, :activity)` stands for a live event of the page, such as a PubSub broadcast: it
  redraws the rail, so the page renders the table again with the `url_state` it already holds.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Table.Web.UrlSync
  alias MishkaGervaz.Test.Web.GatedItem

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_user: @master, activity: 0, url_state: nil)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, assign(socket, :url_state, UrlSync.decode(params, uri, GatedItem))}
  end

  @impl true
  def handle_info(:activity, socket), do: {:noreply, update(socket, :activity, &(&1 + 1))}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={MishkaGervaz.Table.Web.Live}
      id="items"
      resource={GatedItem}
      current_user={@current_user}
      url_state={@url_state}
      url_sync={@live_action == :writes_url}
    >
      <:rail>
        <p id="activity">{@activity}</p>
      </:rail>
    </.live_component>
    """
  end
end
