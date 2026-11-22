defmodule MishkaGervaz.Table.Web.FooterLoadMoreLiveTest do
  @moduledoc """
  Load more in the table's footer row (`pagination do ui do load_more_at :footer end end`), driven
  the way a reader drives it (`MishkaGervaz.Test.Web.LedgerItem`, two rows a page read by keyset,
  on `MishkaGervaz.Test.Web.TablePageLive`'s `/ledger`).

  The button stands at the end of the footer row, beside the page's `table_footer` slot, and the
  pager draws none. A press streams the next page under the rows shown; the slot's counts follow,
  with `more?` while rows are left. A page's own button loads the same with `Live.load_more/2`.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{Branch, LedgerItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @footer ~s|#items [data-role="gervaz-table-footer"]|
  @button ~s|#items [data-role="gervaz-table-footer"] [data-role="gervaz-load-more"]|

  setup do
    on_exit(fn ->
      LedgerItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
      Branch |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)

    site = Ash.create!(Branch, %{name: "North shop"})

    entries =
      for n <- 1..5,
          do: Ash.create!(LedgerItem, %{title: "Entry #{n}", site_id: site.id}, tenant: site.id)

    %{entries: entries}
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/ledger")
    render_async(view)
    view
  end

  defp shown(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#items_ledger_items [id^="items_ledger_items-"]|)
    |> Enum.count()
  end

  test "stands in the footer row, labelled, and the pager draws none" do
    view = open()

    assert has_element?(view, @button, "Load older entries")
    assert has_element?(view, "#{@footer} #counts", "2 of 5")
    assert has_element?(view, "#{@footer} #more")
    refute has_element?(view, ~s|#items [data-role="gervaz-pagination"] [phx-click="load_more"]|)
  end

  test "streams the next page under the rows shown until none is left" do
    view = open()
    assert shown(view) == 2

    view |> element(@button) |> render_click()
    render_async(view)

    assert shown(view) == 4
    assert has_element?(view, "#counts", "4 of 5")

    view |> element(@button) |> render_click()
    render_async(view)

    assert shown(view) == 5
    refute has_element?(view, @button)
    refute has_element?(view, "#more")
  end

  test "a page's own button loads the next page with Live.load_more/2" do
    view = open()

    view |> element("#older") |> render_click()
    render_async(view)

    assert shown(view) == 4
  end
end
