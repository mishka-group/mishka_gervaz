defmodule MishkaGervaz.Table.Web.PageEventsLiveTest do
  @moduledoc """
  The table's page events, `go_to_page` and `change_page_size`, sent with any params, as a browser
  can send them.

  A page that is not a positive whole number opens page 1, and so does a page whose offset the
  database cannot read, as such a page from the URL does. Every page that fits opens, so a table
  that keeps no count is not capped. A page size that is not a positive whole number is ignored, so
  the loads after it still read.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{FeedItem, GatedItem, LoadGate}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @last_readable div(9_223_372_036_854_775_807, 20) + 1
  @not_whole ["two", "1.5", "", " 2", "2abc", "0", "-3", ["2"], %{"a" => "2"}]

  setup do
    start_supervised!(LoadGate)

    on_exit(fn ->
      for resource <- [GatedItem, FeedItem] do
        resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
      end
    end)

    Ash.create!(GatedItem, %{title: "A draft", status: "draft"})
    Ash.create!(GatedItem, %{title: "A published one", status: "published"})
    Ash.create!(FeedItem, %{title: "A post"})
    :ok
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp send_event(view, event, params) do
    view |> with_target("#items") |> render_hook(event, params)
    render_async(view, @await)
  end

  defp pick(view, status) do
    view
    |> element("#items_gated_items-filter")
    |> render_change(%{"status" => status})
  end

  defp shown(view) do
    render_async(view, @await)

    shown = for item <- Ash.read!(GatedItem), row?(view, item), do: item.status
    Enum.sort(shown)
  end

  defp row?(view, item), do: has_element?(view, "#items_gated_items-#{item.id}")

  describe "go_to_page" do
    test "with a page that is not a positive whole number opens page 1" do
      view = open("/items")

      for page <- @not_whole do
        send_event(view, "go_to_page", %{"page" => page})

        assert {page, shown(view)} == {page, ["draft", "published"]}
      end
    end

    test "with a page past the last on a counted table stays on its last page" do
      view = open("/items")

      send_event(view, "go_to_page", %{"page" => "99999999999999999999999"})

      assert shown(view) == ["draft", "published"]
    end

    test "on a table that keeps no count opens any page the database can read" do
      view = open("/feed")

      send_event(view, "go_to_page", %{"page" => to_string(@last_readable)})

      assert_patch(view, "/feed?page=#{@last_readable}")
    end

    test "on a table that keeps no count opens page 1 for a page the database cannot read" do
      for page <- [@last_readable + 1, 99_999_999_999_999_999_999_999] do
        view = open("/feed")

        send_event(view, "go_to_page", %{"page" => "2"})
        assert_patch(view, "/feed?page=2")

        send_event(view, "go_to_page", %{"page" => to_string(page)})
        assert_patch(view, "/feed")
      end
    end
  end

  describe "change_page_size" do
    test "with a size that is not a positive whole number keeps the page size" do
      for size <- @not_whole do
        view = open("/items")
        send_event(view, "change_page_size", %{"size" => "1"})
        pick(view, "draft")

        send_event(view, "change_page_size", %{"size" => size})
        pick(view, "published")

        assert {size, shown(view)} == {size, ["published"]}
      end
    end
  end
end
