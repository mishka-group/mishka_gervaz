defmodule MishkaGervaz.Form.Web.SearchMultiSelectedLiveTest do
  @moduledoc """
  The chips of a `:search_multi` relation on an edit form (`MishkaGervaz.Test.Web.CrateItem` on
  `MishkaGervaz.Test.Web.CratePageLive`): each picked record shows by its label, a record the
  field's `load` leaves out of the options included. Its open list closes on Escape, wherever the
  focus is, and the focus goes back to its search input.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{CrateItem, CrateTag}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @chips ~s|#crate-form [data-role="gervaz-multi-selected"] > span|

  setup do
    on_exit(fn ->
      for resource <- [CrateItem, CrateTag],
          do: resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)
  end

  defp edit(crate) do
    {:ok, view, _html} = live(build_conn(), "/crates?id=#{crate.id}")
    render_async(view)
    view
  end

  defp chips(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(@chips)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  test "a picked record the field's load leaves out shows by its label" do
    fragile = Ash.create!(CrateTag, %{name: "Fragile", active: false})
    view = edit(Ash.create!(CrateItem, %{title: "Glass", tag_ids: [fragile.id]}))

    assert chips(view) == ["Fragile"]
  end

  test "picked records in and out of the load each show by their label" do
    heavy = Ash.create!(CrateTag, %{name: "Heavy"})
    fragile = Ash.create!(CrateTag, %{name: "Fragile", active: false})
    view = edit(Ash.create!(CrateItem, %{title: "Glass", tag_ids: [heavy.id, fragile.id]}))

    assert Enum.sort(chips(view)) == ["Fragile", "Heavy"]
  end

  test "a save that leaves the field keeps the picked records" do
    fragile = Ash.create!(CrateTag, %{name: "Fragile", active: false})
    crate = Ash.create!(CrateItem, %{title: "Glass", tag_ids: [fragile.id]})
    view = edit(crate)

    view |> form("#crate-form", %{"form" => %{"title" => "Thin glass"}}) |> render_submit()

    assert %{title: "Thin glass", tag_ids: [id]} = Ash.get!(CrateItem, crate.id)
    assert id == fragile.id
  end

  describe "the open list" do
    @list ~s|#crate-form [data-role="gervaz-relation-list"]|

    defp opened(view) do
      view
      |> element(~s|#crate-form [id^="multi-select-"][id$="-tag_ids"]|)
      |> render_hook("relation_focus", %{"filter" => "tag_ids"})

      view
    end

    test "closes on Escape pressed anywhere on the page" do
      Ash.create!(CrateTag, %{name: "Heavy"})
      view = edit(Ash.create!(CrateItem, %{title: "Glass"})) |> opened()
      assert has_element?(view, @list)

      view |> element(@list) |> render_keydown(%{"key" => "Escape"})

      refute has_element?(view, @list)
    end

    test "gives the focus back to its search input as it closes" do
      Ash.create!(CrateTag, %{name: "Heavy"})
      view = edit(Ash.create!(CrateItem, %{title: "Glass"})) |> opened()

      [input_id] =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(~s|#crate-form input[name="_search_tag_ids"]|)
        |> LazyHTML.attribute("id")

      [keydown] =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(@list)
        |> LazyHTML.attribute("phx-window-keydown")

      assert ["focus", %{"to" => "#" <> ^input_id}] =
               keydown |> JSON.decode!() |> Enum.find(&match?(["focus", _], &1))
    end
  end
end
