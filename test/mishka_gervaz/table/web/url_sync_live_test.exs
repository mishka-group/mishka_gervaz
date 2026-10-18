defmodule MishkaGervaz.Table.Web.UrlSyncLiveTest do
  @moduledoc """
  A table on a page that hands it `url_state`, driven the way a reader drives it.

  The page renders the table again whenever something of its own changes, handing it the same
  `url_state` each time. A URL the table has already taken changes nothing, so a filter the reader
  picked stays, whether its load is still running or the table never writes the URL. A URL the
  reader goes to — a patch, the Back button — is followed, its load replacing the running one.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{GatedItem, LoadGate}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000

  setup do
    start_supervised!(LoadGate)

    on_exit(fn -> GatedItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{
      draft: Ash.create!(GatedItem, %{title: "A draft", status: "draft"}),
      published: Ash.create!(GatedItem, %{title: "A published one", status: "published"})
    }
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp pick(view, status) do
    view
    |> element("#items_gated_items-filter")
    |> render_change(%{"status" => status})
  end

  defp redraw_page(view) do
    send(view.pid, :activity)
    render(view)
  end

  defp shown(view) do
    render_async(view, @await)

    shown = for item <- Ash.read!(GatedItem), row?(view, item), do: item.status
    Enum.sort(shown)
  end

  defp row?(view, item), do: has_element?(view, "#items_gated_items-#{item.id}")

  describe "the page re-renders while a pick loads" do
    test "the pick stays, and its URL is written" do
      view = open("/items")
      assert shown(view) == ["draft", "published"]

      LoadGate.close()
      pick(view, "draft")
      redraw_page(view)
      LoadGate.open()

      assert shown(view) == ["draft"]
      assert_patch(view, "/items?filter_status=draft")
    end
  end

  describe "a table that does not write the URL" do
    test "keeps a pick when the page re-renders" do
      view = open("/items/fixed")

      pick(view, "draft")
      assert shown(view) == ["draft"]

      redraw_page(view)
      assert shown(view) == ["draft"]
    end
  end

  describe "a URL the reader goes to" do
    test "is followed while a pick loads" do
      view = open("/items?filter_status=published")
      assert shown(view) == ["published"]

      LoadGate.close()
      pick(view, "draft")
      render_patch(view, "/items")
      LoadGate.open()

      assert shown(view) == ["draft", "published"]
    end

    test "is followed after the table wrote its own" do
      view = open("/items")

      pick(view, "draft")
      assert shown(view) == ["draft"]
      assert_patch(view, "/items?filter_status=draft")

      render_patch(view, "/items")
      assert shown(view) == ["draft", "published"]
    end
  end
end
