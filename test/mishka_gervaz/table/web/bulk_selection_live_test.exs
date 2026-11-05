defmodule MishkaGervaz.Table.Web.BulkSelectionLiveTest do
  @moduledoc """
  The bulk bar's count of picked rows, driven the way a reader drives it, while a search hides some
  of them.

  A bulk action reaches only the rows the table's read finds, so the bar counts the picked rows the
  read still finds and names how many the filters hide. A load that starts the list afresh while
  rows are picked reads which of them it still finds, in one read of their ids; a load with no
  picked rows reads nothing more. A picked row realtime moves out of the view, or back, follows
  with no read of its own.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Queries
  alias MishkaGervaz.Test.Web.PlainItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000

  setup do
    on_exit(fn -> PlainItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{items: Enum.map(~w(a b c), &Ash.create!(PlainItem, %{title: &1}))}
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

  defp search(view, text) do
    view |> element("#items_plain_items-filter") |> render_change(%{"search" => text})
    render_async(view, @await)
  end

  defp wipe(view) do
    view
    |> element(~s|#items [phx-click="bulk_action"][phx-value-action="wipe"]|)
    |> render_click()

    render_async(view, @await)
  end

  defp notify(view, action_name, record) do
    notification = %Ash.Notifier.Notification{
      resource: PlainItem,
      action: Ash.Resource.Info.action(PlainItem, action_name),
      data: record
    }

    send(view.pid, {:notify, notification})
    render(view)
    render(view)
    render_async(view, @await)
  end

  defp bar(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#items [phx-click*="clear_selection"]|)
    |> Enum.empty?()
    |> case do
      true -> nil
      false -> view |> render() |> label()
    end
  end

  defp label(html) do
    [label] = Regex.run(~r/\d+ selected(, \d+ hidden by the filters)?/, html, capture: :first)
    label
  end

  test "counts only the picked rows the search shows, and names the ones it hides", %{
    items: [a, b, _c]
  } do
    view = open("/plain")
    pick(view, a)
    assert bar(view) == "1 selected"

    search(view, "b")
    pick(view, b)
    assert bar(view) == "1 selected, 1 hidden by the filters"

    search(view, "")
    assert bar(view) == "2 selected"
  end

  test "the bulk action reaches the rows the bar counts", %{items: [a, b, _c]} do
    view = open("/plain")
    pick(view, a)
    search(view, "b")
    pick(view, b)
    assert bar(view) == "1 selected, 1 hidden by the filters"

    wipe(view)

    assert PlainItem |> Ash.read!() |> Enum.map(& &1.title) |> Enum.sort() == ~w(a c)
  end

  test "a picked row edited elsewhere out of the search leaves the count, and back into it returns",
       %{items: [a | _]} do
    view = open("/plain")
    search(view, "a")
    pick(view, a)

    a = Ash.update!(a, %{title: "z"})
    notify(view, :update, a)
    assert bar(view) == "0 selected, 1 hidden by the filters"

    a = Ash.update!(a, %{title: "a2"})
    notify(view, :update, a)
    assert bar(view) == "1 selected"
  end

  test "a search reads the picked rows once while rows are picked, and nothing more otherwise", %{
    items: [a | _]
  } do
    view = open("/plain")
    {_view, without_picks} = Queries.count(fn -> search(view, "b") end)
    search(view, "")

    pick(view, a)
    {_view, with_picks} = Queries.count(fn -> search(view, "b") end)

    assert with_picks == without_picks + 1
  end
end
