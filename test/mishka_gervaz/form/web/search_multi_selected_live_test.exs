defmodule MishkaGervaz.Form.Web.SearchMultiSelectedLiveTest do
  @moduledoc """
  The chips of a `:search_multi` relation on an edit form (`MishkaGervaz.Test.Web.CrateItem` on
  `MishkaGervaz.Test.Web.CratePageLive`): each picked record shows by its label, a record the
  field's `load` leaves out of the options included.
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
end
