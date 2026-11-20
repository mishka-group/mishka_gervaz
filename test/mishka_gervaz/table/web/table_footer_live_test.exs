defmodule MishkaGervaz.Table.Web.TableFooterLiveTest do
  @moduledoc """
  The `:table_footer` slot of a table, driven the way a reader drives it
  (`MishkaGervaz.Test.Web.ShelfItem`, three rows a page, on `MishkaGervaz.Test.Web.TablePageLive`'s
  `/shelf`).

  The slot is drawn under the rows with the table's counts, the rows shown and the total, and
  carries the page's own text and button. It follows the page shown and a row deleted, and a table
  with nothing to show draws its empty state instead.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Test.Web.ShelfItem

  @endpoint MishkaGervaz.Test.Web.Endpoint

  setup do
    on_exit(fn -> ShelfItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    :ok
  end

  defp seed(count), do: Enum.map(1..count//1, &Ash.create!(ShelfItem, %{title: "item #{&1}"}))

  defp open(path \\ "/shelf") do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  test "shows the rows shown and the total with the page's own button" do
    seed(5)
    view = open()

    assert has_element?(view, ~s|#items [data-role="gervaz-table-footer"] #counts|, "3 of 5")

    view |> element("#add-item") |> render_click()
    assert has_element?(view, "#activity", "1")
  end

  test "follows the page shown and a row deleted" do
    [first | _] = seed(5)
    view = open()

    view |> element(~s|#items [phx-click="go_to_page"][phx-value-page="2"]|) |> render_click()
    render_async(view)
    assert has_element?(view, "#counts", "2 of 5")

    view = open()
    view |> element(~s|#items [phx-click="delete"][phx-value-id="#{first.id}"]|) |> render_click()
    render_async(view)

    assert has_element?(view, "#counts", "2 of 4")
  end

  test "a table with nothing to show draws no footer" do
    view = open()

    refute has_element?(view, ~s|#items [data-role="gervaz-table-footer"]|)
  end

  describe "Shared.table_counts/1" do
    test "counts the rows from the view's first page to its last" do
      static = %{keep_loaded_records: false, page_size: 10}

      assert %{shown: 10, total: 25} =
               Shared.table_counts(%{
                 static: static,
                 next_offset: 20,
                 first_page: 2,
                 current_page_size: nil,
                 total_count: 25
               })

      assert %{shown: 5, total: 25} =
               Shared.table_counts(%{
                 static: static,
                 next_offset: 25,
                 first_page: 3,
                 current_page_size: nil,
                 total_count: 25
               })
    end

    test "counts the rows a table that keeps them holds, and a missing total is nil" do
      assert %{shown: 2, total: nil} =
               Shared.table_counts(%{
                 static: %{keep_loaded_records: true},
                 loaded_records: [%{}, %{}],
                 total_count: nil
               })
    end
  end
end
