defmodule MishkaGervaz.Form.Web.DeriveValueLiveTest do
  @moduledoc """
  A virtual field's `derive_value` on an edit form (`MishkaGervaz.Test.Web.CrateItem` on
  `MishkaGervaz.Test.Web.CratePageLive`): a number and a unit derived from one stored value draw
  what the record holds, and save it back unchanged when the reader leaves them.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.CrateItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#crate-form"

  setup do
    on_exit(fn -> CrateItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp edit(crate) do
    {:ok, view, _html} = live(build_conn(), "/crates?id=#{crate.id}")
    render_async(view)
    view
  end

  defp weight_input(view, value),
    do: has_element?(view, ~s|#{@form} input[name="form[weight]"][value="#{value}"]|)

  defp unit_picked(view, unit),
    do:
      has_element?(
        view,
        ~s|#{@form} select[name="form[weight_unit]"] option[selected][value="#{unit}"]|
      )

  test "an edit form draws the number and unit derived from the stored value" do
    view = edit(Ash.create!(CrateItem, %{title: "Bolts", weight_grams: 5000}))

    assert weight_input(view, "5")
    assert unit_picked(view, "kg")
  end

  test "another stored value derives another unit" do
    view = edit(Ash.create!(CrateItem, %{title: "Nuts", weight_grams: 750}))

    assert weight_input(view, "750")
    assert unit_picked(view, "g")
  end

  test "a save that leaves the derived fields keeps the stored value" do
    crate = Ash.create!(CrateItem, %{title: "Bolts", weight_grams: 5000})
    view = edit(crate)

    view |> form(@form, %{"form" => %{"title" => "Big bolts"}}) |> render_submit()

    assert %{title: "Big bolts", weight_grams: 5000} = Ash.get!(CrateItem, crate.id)
  end

  test "a save with a new number and unit stores the value they make" do
    crate = Ash.create!(CrateItem, %{title: "Bolts", weight_grams: 5000})
    view = edit(crate)

    view
    |> form(@form, %{"form" => %{"weight" => "1200", "weight_unit" => "g"}})
    |> render_submit()

    assert %{weight_grams: 1200} = Ash.get!(CrateItem, crate.id)
  end
end
