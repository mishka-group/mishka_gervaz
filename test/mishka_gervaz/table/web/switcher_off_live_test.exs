defmodule MishkaGervaz.Table.Web.SwitcherOffLiveTest do
  @moduledoc """
  `template_options switcher: false` on a table that declares `switchable_templates`, driven the way
  a reader drives it (`MishkaGervaz.Test.Web.ShelfItem` on `MishkaGervaz.Test.Web.TablePageLive`'s
  `/shelf`, beside `MishkaGervaz.Test.Web.KeptItem` on `/kept`, which keeps its switcher).

  The table draws no switcher, in either template, and its templates stay reachable from the URL.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Test.Web.ShelfItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @switch ~s|#items [phx-click="switch_template"]|

  setup do
    on_exit(fn -> ShelfItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    Ash.create!(ShelfItem, %{title: "apple"})
    :ok
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  test "a table that turned it off draws no switcher" do
    refute has_element?(open("/shelf"), @switch)
  end

  test "a table that did not keeps its switcher" do
    assert has_element?(open("/kept"), @switch)
  end

  test "its other template stays reachable from the URL, and draws no switcher either" do
    view = open("/shelf?template=media_gallery")

    refute has_element?(view, ~s|#items [data-role="gervaz-table-frame"]|)
    refute has_element?(view, @switch)
  end

  describe "Shared.show_switcher?/1" do
    @two [MishkaGervaz.Table.Templates.Table, MishkaGervaz.Table.Templates.MediaGallery]

    test "is on for two or more templates unless the options turn it off" do
      assert Shared.show_switcher?(%{switchable_templates: @two, template_options: []})
      assert Shared.show_switcher?(%{switchable_templates: @two, template_options: nil})

      refute Shared.show_switcher?(%{
               switchable_templates: @two,
               template_options: [switcher: false]
             })

      refute Shared.show_switcher?(%{switchable_templates: [], template_options: []})
    end
  end
end
