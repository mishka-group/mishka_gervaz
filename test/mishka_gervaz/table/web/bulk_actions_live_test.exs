defmodule MishkaGervaz.Table.Web.BulkActionsLiveTest do
  @moduledoc """
  A table's bulk actions as the resource declares them, driven the way a reader drives them.

  A `type :update` bulk action runs the Ash action its `action` names, the master's one for a
  master.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.KeptItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @finish ~s|#items [phx-click="bulk_action"][phx-value-action="finish"]|

  setup do
    on_exit(fn -> KeptItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{items: Enum.map(~w(a b), &Ash.create!(KeptItem, %{title: &1}))}
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp pick(view, item) do
    view
    |> element(~s|#items [phx-click="toggle_select"][phx-value-id="#{item.id}"]|)
    |> render_click()
  end

  test "a type :update bulk action runs the Ash action it names", %{items: [a, b]} do
    view = open("/kept")
    pick(view, b)

    view |> element(@finish) |> render_click()
    render_async(view, @await)

    assert %{done: true} = Ash.get!(KeptItem, b.id)
    assert %{done: false} = Ash.get!(KeptItem, a.id)
  end
end
