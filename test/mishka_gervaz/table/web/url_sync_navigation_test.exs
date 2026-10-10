defmodule MishkaGervaz.Table.Web.UrlSyncNavigationTest do
  @moduledoc """
  A bidirectional table writes its state into the URL after a load, and takes the next URL the page
  hands it as that write coming back only when it is the very URL it wrote. Any other URL is the
  reader's navigation — a link to the bare page, the Back button — and the table follows it. A URL
  that is already the one in the address bar is not written again, so no write is left waiting.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.{DataLoader, Live, State, UrlSync}
  alias MishkaGervaz.Test.Resources.Post

  @master %{id: "master-1", site_id: nil, role: :admin}

  defp state(updates) do
    "table"
    |> State.init(Post, @master)
    |> State.update(Keyword.merge([loading: :loaded, base_path: "/posts"], updates))
  end

  defp socket(state, assigns) do
    %Phoenix.LiveView.Socket{private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}}
    |> Phoenix.Component.assign(
      Map.merge(
        %{
          table_state: state,
          id: state.static.id,
          initialized: true,
          subscribed: false,
          refresh_initialized: false,
          url_sync_pending: false
        },
        assigns
      )
    )
    |> Phoenix.LiveView.stream(state.static.stream_name, [])
  end

  defp visit(socket, url) do
    query = url |> URI.parse() |> Map.get(:query) |> Kernel.||("") |> URI.decode_query()

    {:ok, socket} =
      Live.update(
        %{
          id: "table",
          resource: Post,
          current_user: @master,
          url_state: UrlSync.decode(query, url, Post)
        },
        socket
      )

    socket
  end

  describe "a URL the page hands the table" do
    test "is the reader's navigation when it is not the one the table wrote" do
      socket =
        [filter_values: %{status: "published"}]
        |> state()
        |> socket(%{url_sync_pending: "/posts?filter_status=published&sort=title%3Aasc"})
        |> visit("/posts")

      assert socket.assigns.table_state.filter_values == %{}
      assert socket.assigns.url_sync_pending == false
    end

    test "is the table's own write coming back when it is the very URL, in any order" do
      socket =
        [filter_values: %{status: "published"}, sort_fields: [{:title, :asc}]]
        |> state()
        |> socket(%{url_sync_pending: "/posts?filter_status=published&sort=title%3Aasc"})
        |> visit("/posts?sort=title%3Aasc&filter_status=published")

      assert socket.assigns.table_state.filter_values == %{status: "published"}
      assert socket.assigns.url_sync_pending == false

      assert socket.assigns.url_seen ==
               {"/posts", %{"filter_status" => "published", "sort" => "title:asc"}}
    end
  end

  describe "after a load" do
    defp loaded(socket) do
      DataLoader.handle_async(
        :load_data,
        {:ok, {1, %{results: [], more?: false}, true, %{total_count: 0, total_pages: 1}}},
        socket
      )
    end

    test "the URL already in the address bar is not written again" do
      socket =
        [filter_values: %{}, sort_fields: [{:title, :asc}]]
        |> state()
        |> socket(%{url_seen: {"/posts", %{"sort" => "title:asc"}}})
        |> loaded()

      assert socket.redirected == nil
      assert socket.assigns.url_sync_pending == false
    end

    test "a new one is written, and the table waits for that very URL" do
      socket =
        [filter_values: %{}, sort_fields: [{:title, :asc}]]
        |> state()
        |> socket(%{url_seen: {"/posts", %{}}})
        |> loaded()

      assert {:live, :patch, %{to: "/posts?sort=title%3Aasc", kind: :replace}} = socket.redirected
      assert socket.assigns.url_sync_pending == "/posts?sort=title%3Aasc"
    end
  end
end
