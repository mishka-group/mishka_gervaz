defmodule MishkaGervaz.Table.Web.SkeletonLiveTest do
  @moduledoc """
  The placeholder rows a table draws while it reads with no rows to show, driven the way a reader
  drives it (`MishkaGervaz.Test.Web.GatedItem` on `/items`, whose loads `MishkaGervaz.Test.Web.LoadGate`
  holds). They stand where the rows go, inside the table's frame under its header, so the table
  keeps its room: before the first read, and after a filter that found nothing when the reader
  picks another. A read over rows shown keeps those rows under a veil instead.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Test.Web.{GatedItem, LoadGate}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @filters "#items_gated_items-filter"
  @skeleton ~s|#items [data-role="gervaz-table-frame"] [data-role="gervaz-skeleton"]|

  setup do
    start_supervised!(LoadGate)
    on_exit(fn -> GatedItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{draft: Ash.create!(GatedItem, %{title: "A draft", status: "draft"})}
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/items")
    render_async(view)
    view
  end

  defp pick(view, status), do: view |> element(@filters) |> render_change(%{"status" => status})

  test "before its first read, draws placeholder rows in the table's frame" do
    LoadGate.close()
    {:ok, view, _html} = live(build_conn(), "/items")

    assert has_element?(
             view,
             ~s|[data-role="gervaz-table-frame"] [data-role="gervaz-skeleton"][data-rows="5"]|
           )

    LoadGate.open()
    render_async(view)

    refute has_element?(view, ~s|[data-role="gervaz-skeleton"]|)
  end

  test "a read after a filter that found nothing stands placeholder rows in the empty state's place",
       %{draft: draft} do
    view = open()
    pick(view, "published")
    render_async(view)
    assert has_element?(view, "#items", "No records found")

    LoadGate.close()
    pick(view, "draft")

    assert has_element?(view, @skeleton)
    refute has_element?(view, "#items", "No records found")

    LoadGate.open()
    render_async(view)

    refute has_element?(view, @skeleton)
    assert has_element?(view, "#items_gated_items-#{draft.id}")
  end

  test "a read over rows shown keeps them, with no placeholder rows", %{draft: draft} do
    view = open()

    LoadGate.close()
    pick(view, "published")

    assert has_element?(view, "#items_gated_items-#{draft.id}")
    refute has_element?(view, @skeleton)

    LoadGate.open()
    render_async(view)
  end

  describe "Shared.skeleton_rows/2" do
    test "is the template's skeleton_rows, else the page size up to five" do
      assert Shared.skeleton_rows(%{template_options: [skeleton_rows: 8], page_size: 20}, %{}) ==
               8

      assert Shared.skeleton_rows(%{template_options: [], page_size: 3}, %{current_page_size: nil}) ==
               3

      assert Shared.skeleton_rows(%{template_options: nil, page_size: 20}, %{
               current_page_size: 50
             }) == 5

      assert Shared.skeleton_rows(nil, nil) == 5
    end
  end
end
