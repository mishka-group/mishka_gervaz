defmodule MishkaGervaz.Table.Web.RowDrawerLiveTest do
  @moduledoc """
  A row action of type `:drawer`, driven the way a reader drives it (`MishkaGervaz.Test.Web.DeskItem`
  on `MishkaGervaz.Test.Web.TablePageLive`'s `/desk`).

  The row's record view opens in the table's drawer, its head built from the row: icon tile, title,
  sub line, chips and actions. The resource's form opens in a bottom sheet editing the row, and a
  save the page answers with `close_drawer/2` closes it and puts the saved row back in its place.
  The close button closes the drawer, and a row that is gone opens nothing.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.DeskItem

  @endpoint MishkaGervaz.Test.Web.Endpoint

  setup do
    on_exit(fn -> DeskItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    :ok
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/desk")
    render_async(view)
    view
  end

  defp press(view, action, record) do
    view
    |> element(
      ~s|#items [phx-click="open_drawer"][phx-value-action="#{action}"][phx-value-id="#{record.id}"]|
    )
    |> render_click()
  end

  test "opens the row's record view in a drawer with the head built from the row" do
    lamp = Ash.create!(DeskItem, %{title: "Lamp", owner: "Jane"})
    Ash.create!(DeskItem, %{title: "Desk"})
    view = open()

    press(view, :peek, lamp)

    assert has_element?(view, ~s|#items-row-drawer[data-role="gervaz-drawer"]|)
    assert has_element?(view, "#items-row-drawer-title", "Lamp")
    assert has_element?(view, "#items-row-drawer-sub", "Owned by Jane")

    assert has_element?(
             view,
             ~s|#items-row-drawer [data-role="gervaz-panel-tile"][data-tone="ok"]|
           )

    assert has_element?(view, ~s|#items-row-drawer [data-role="gervaz-panel-chip"]|, "Owned")
    assert has_element?(view, "#items-row-drawer #peek-id", lamp.id)

    view |> element("#items-row-drawer #copy-item") |> render_click()
    assert has_element?(view, "#activity", "1")
  end

  test "the close button closes the drawer" do
    lamp = Ash.create!(DeskItem, %{title: "Lamp"})
    view = open()

    press(view, :peek, lamp)
    assert has_element?(view, "#items-row-drawer-sub", "Owned by nobody")

    view |> element(~s|#items-row-drawer [data-role="gervaz-panel-close"]|) |> render_click()

    refute has_element?(view, "#items-row-drawer")
  end

  test "opens the form in a sheet editing the row, and a save closes it and redraws the row" do
    lamp = Ash.create!(DeskItem, %{title: "Lamp"})
    view = open()

    press(view, :edit_here, lamp)
    render_async(view)

    assert has_element?(view, ~s|#items-row-drawer[data-role="gervaz-sheet"]|)
    assert has_element?(view, "#items-row-drawer-title", "Edit item")

    form = ~s|#items-row-drawer #items-drawer-form-form|
    assert view |> element(form) |> render() =~ "Lamp"

    view |> form(form, form: %{title: "Desk lamp"}) |> render_submit()
    render_async(view)

    refute has_element?(view, "#items-row-drawer")
    assert has_element?(view, "#items", "Desk lamp")
    assert Ash.get!(DeskItem, lamp.id).title == "Desk lamp"
  end

  test "a row that is gone opens nothing" do
    lamp = Ash.create!(DeskItem, %{title: "Lamp"})
    view = open()
    Ash.destroy!(lamp)

    press(view, :peek, lamp)

    refute has_element?(view, "#items-row-drawer")
  end
end
