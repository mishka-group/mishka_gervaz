defmodule MishkaGervaz.Table.Web.LoadMoreUrlLiveTest do
  @moduledoc """
  A load-more table that writes its page to the URL, opened at that URL the way a reader reloads
  it, on `MishkaGervaz.Test.Web.FeedItem`'s `/feed` table: 20 rows a page, read at most 15 at a
  time.

  A reload at page N shows every row up to page N, the rows the reader had, and Load more goes on
  with page N + 1. A page short of rows shows the rows there are; a page past the last row shows
  none.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.FeedItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000

  setup do
    on_exit(fn -> FeedItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp create_rows(count), do: Enum.each(1..count, &Ash.create!(FeedItem, %{title: title(&1)}))

  defp title(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")

  defp titles(numbers), do: Enum.map(numbers, &title/1)

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp load_more(view) do
    view |> element("#items button[phx-click=load_more]") |> render_click()
    render_async(view, @await)
  end

  defp more?(view), do: has_element?(view, "#items button[phx-click=load_more]")

  defp shown(view) do
    rows = Map.new(Ash.read!(FeedItem), &{"items_feed_items-#{&1.id}", &1.title})

    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#items [id]")
    |> LazyHTML.attribute("id")
    |> Enum.flat_map(&List.wrap(rows[&1]))
  end

  describe "a reload at a URL page past 1" do
    test "shows every row up to that page, and Load more goes on with the next" do
      create_rows(70)
      view = open("/feed?page=2")

      assert shown(view) == titles(1..40)
      assert more?(view)

      load_more(view)

      assert_patch(view, "/feed?page=3")
      assert shown(view) == titles(1..60)
      assert more?(view)
    end

    test "at a page short of rows shows every row there is" do
      create_rows(50)
      view = open("/feed?page=3")

      assert shown(view) == titles(1..50)
      refute more?(view)
    end

    test "at a page past the last row shows no rows" do
      create_rows(50)
      view = open("/feed?page=4")

      assert shown(view) == []
      refute more?(view)
    end
  end
end
