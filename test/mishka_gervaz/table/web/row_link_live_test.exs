defmodule MishkaGervaz.Table.Web.RowLinkLiveTest do
  @moduledoc """
  A table whose `row do path … end` makes the whole row open a path, driven the way a reader drives
  it (`MishkaGervaz.Test.Web.ShelfItem` on `MishkaGervaz.Test.Web.TablePageLive`'s `/shelf`).

  Each row carries a link over it to its path, named by the row's first column for a screen reader
  and reached with Tab. The row's checkbox and actions stand above the link and keep their own
  clicks. A table without `path` draws no link.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{PlainItem, ShelfItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @link ~s|[data-role="gervaz-row-link"]|

  setup do
    on_exit(fn ->
      for resource <- [ShelfItem, PlainItem],
          do: resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)

    %{items: Enum.map(~w(apple pear), &Ash.create!(ShelfItem, %{title: &1}))}
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  test "each row carries a link to its path, named by its first column", %{items: [apple, _]} do
    view = open("/shelf")

    assert has_element?(
             view,
             ~s|#items [id$="-#{apple.id}"] a#{@link}[href="/shelf/#{apple.id}"]|,
             "apple"
           )

    assert view |> element(~s|#items a#{@link}[href="/shelf/#{apple.id}"]|) |> render() =~
             "sr-only"
  end

  test "a click on the row's link opens its path", %{items: [apple, _]} do
    view = open("/shelf")

    assert {:error, {:live_redirect, %{to: to}}} =
             view |> element(~s|#items a#{@link}[href="/shelf/#{apple.id}"]|) |> render_click()

    assert to == "/shelf/#{apple.id}"
  end

  test "the checkbox and the actions stand above the link and keep their clicks",
       %{items: [apple, _]} do
    view = open("/shelf")
    row = ~s|#items [id$="-#{apple.id}"]|

    assert has_element?(view, ~s|#{row} div.z-\\[1\\]:has([phx-click="toggle_select"])|)
    assert has_element?(view, ~s|#{row} [data-role="gervaz-row-actions"].z-\\[1\\]|)

    view |> element(~s|#{row} [phx-click="toggle_select"]|) |> render_click()

    assert has_element?(view, ~s|#{row} [phx-click="toggle_select"][checked]|)
  end

  test "a table without a path draws no link" do
    Ash.create!(PlainItem, %{title: "plain"})
    view = open("/plain")

    refute has_element?(view, ~s|#items #{@link}|)
  end
end
