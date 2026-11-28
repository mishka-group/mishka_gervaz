defmodule MishkaGervaz.Form.Web.UploadAnyTypeLiveTest do
  @moduledoc """
  An upload that names no `accept` (`MishkaGervaz.Test.Web.CrateItem` on
  `MishkaGervaz.Test.Web.CratePageLive`): the form mounts and its file input takes a file of any
  type.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.CrateItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @input ~s|#crate-form input[type="file"]|

  setup do
    on_exit(fn -> CrateItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp accept(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(@input)
    |> LazyHTML.attribute("accept")
  end

  test "a create form mounts with a file input that takes any type" do
    view = open("/crates")

    assert has_element?(view, @input)
    assert accept(view) == []
  end

  test "an edit form mounts with the same file input" do
    crate = Ash.create!(CrateItem, %{title: "Spare parts"})
    view = open("/crates?id=#{crate.id}")

    assert has_element?(view, ~s|#crate-form input[name="form[title]"][value="Spare parts"]|)
    assert has_element?(view, @input)
  end
end
