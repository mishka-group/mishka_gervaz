defmodule MishkaGervaz.Table.Web.LoadMoreOffsetLiveTest do
  @moduledoc """
  Load more on a table that keeps no rows it has loaded, so its rows live only in the stream, and
  whose read action has no keyset pagination, as most admin reads have, driven the way a reader
  drives it while other views change rows over realtime.

  A realtime notification reaches the table in two hand-offs: the page passes it on with
  `send_update`, and the table reads a burst of them in one message it sends itself. `settle/1`
  waits for both, then for any task the read started, before the test looks.

  Load more reads from the offset of the rows the view shows, `next_offset`, so a row another view
  removed, or one the view deleted itself or with a custom action, moves no row past it, and a row
  drawn again is drawn once, in its place. A row that leaves without having been shown, or one that
  arrives, makes that click read a row already shown again, so it adds fewer new rows; a table whose
  read allows keyset pagination reads a full page instead (`MishkaGervaz.Table.Web.LoadMoreLiveTest`).
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.OffsetItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @titles ~w(a b c d e f g h i j)

  setup do
    on_exit(fn -> OffsetItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{items: Enum.map(@titles, &Ash.create!(OffsetItem, %{title: &1}))}
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp load_more(view) do
    view |> element("#items button[phx-click=load_more]") |> render_click()
    render_async(view, @await)
  end

  defp more?(view), do: has_element?(view, "#items button[phx-click=load_more]")

  defp listed(view, items) do
    titles = Map.new(items, &{"items_offset_items-#{&1.id}", &1.title})

    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#items [id^='items_offset_items-']")
    |> LazyHTML.attribute("id")
    |> Enum.flat_map(&List.wrap(titles[&1]))
  end

  defp notify(view, action_name, records) do
    for record <- List.wrap(records) do
      notification = %Ash.Notifier.Notification{
        resource: OffsetItem,
        action: Ash.Resource.Info.action(OffsetItem, action_name),
        data: record
      }

      send(view.pid, {:notify, notification})
    end

    settle(view)
  end

  defp settle(view) do
    render(view)
    render(view)
    render_async(view, @await)
  end

  defp pick(view, item) do
    view
    |> element(~s|#items [phx-click="toggle_select"][phx-value-id="#{item.id}"]|)
    |> render_click()
  end

  defp delete_row(view, item) do
    view
    |> element(~s|#items [phx-click="delete"][phx-value-id="#{item.id}"]|)
    |> render_click()
  end

  defp wipe(view) do
    view
    |> element(~s|#items [phx-click="bulk_action"][phx-value-action="wipe"]|)
    |> render_click()

    render_async(view, @await)
  end

  describe "after rows another view removed" do
    test "passes no row", %{items: [a, b | _] = items} do
      other = open("/offset")
      view = open("/offset")

      pick(other, a)
      pick(other, b)
      wipe(other)
      notify(view, :destroy, [a, b])
      assert listed(view, items) == ~w(c d)

      load_more(view)
      assert listed(view, items) == ~w(c d e f g h)

      load_more(view)
      assert listed(view, items) == ~w(c d e f g h i j)
      refute more?(view)
    end

    test "that it did not show, draws a row it shows once, in its place", %{items: items} do
      view = open("/offset")
      h = Enum.find(items, &(&1.title == "h"))

      Ash.destroy!(h)
      notify(view, :destroy, h)
      assert listed(view, items) == ~w(a b c d)

      load_more(view)
      assert listed(view, items) == ~w(a b c d e f g)

      load_more(view)
      assert listed(view, items) == ~w(a b c d e f g i j)
      refute more?(view)
    end
  end

  describe "after a row it deletes itself" do
    test "passes no row with realtime off", %{items: [_a, b | _] = items} do
      view = open("/offset")

      delete_row(view, b)
      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f g h)
    end

    test "passes no row when a custom action removed it", %{items: [_a, b | _] = items} do
      view = open("/offset")

      view
      |> element(~s|#items [phx-value-event="drop"][phx-value-values*="#{b.id}"]|)
      |> render_click()

      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f g h)
    end

    test "counts it once when its own realtime removal arrives too", %{
      items: [_a, b | _] = items
    } do
      view = open("/offset")

      delete_row(view, b)
      notify(view, :destroy, b)
      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f g h)
    end
  end

  describe "after a row created elsewhere is drawn first" do
    test "draws a row it shows once, in its place, and passes no row", %{items: items} do
      view = open("/offset")
      aa = Ash.create!(OffsetItem, %{title: "aa"})
      items = [aa | items]

      notify(view, :create, aa)
      assert listed(view, items) == ~w(aa a b c d)

      load_more(view)
      assert listed(view, items) == ~w(aa a b c d e f g)

      load_more(view)
      assert listed(view, items) == ~w(aa a b c d e f g h i j)
      refute more?(view)
    end

    test "that sorts after the rows shown, passes no row", %{items: items} do
      view = open("/offset")
      z = Ash.create!(OffsetItem, %{title: "z"})
      items = [z | items]

      notify(view, :create, z)
      assert listed(view, items) == ~w(z a b c d)

      load_more(view)
      assert listed(view, items) == ~w(z a b c d e f g h)

      load_more(view)
      assert listed(view, items) == ~w(z a b c d e f g h i j)
      refute more?(view)
    end
  end

  test "after a row it shows is changed elsewhere, passes no row", %{items: [_a, b | _] = items} do
    view = open("/offset")
    b2 = Ash.update!(b, %{title: "b2"})
    items = Enum.map(items, &if(&1.id == b.id, do: b2, else: &1))

    notify(view, :update, b2)
    assert listed(view, items) == ~w(a b2 c d)

    load_more(view)
    assert listed(view, items) == ~w(a b2 c d e f g h)
  end

  test "after its own bulk destroy, passes no row", %{items: [a, b | _] = items} do
    view = open("/offset")

    pick(view, a)
    pick(view, b)
    wipe(view)
    assert listed(view, items) == ~w(c d e f)

    load_more(view)
    assert listed(view, items) == ~w(c d e f g h i j)
    refute more?(view)
  end

  test "reads one page in one read after rows another view removed", %{items: [a, b | _] = items} do
    view = open("/offset")
    Enum.each([a, b], &Ash.destroy!/1)
    notify(view, :destroy, [a, b])

    {_view, queries} = MishkaGervaz.Test.Queries.count(fn -> load_more(view) end)

    assert queries == 1
    assert listed(view, items) == ~w(c d e f g h)
  end

  test "opened at a later page, Load earlier reads the page before and Load more goes on after",
       %{
         items: items
       } do
    view = open("/offset?page=2")
    assert listed(view, items) == ~w(e f g h)

    view |> element("#items button[phx-click=load_earlier]") |> render_click()
    render_async(view, @await)
    assert listed(view, items) == ~w(a b c d e f g h)
    refute has_element?(view, "#items button[phx-click=load_earlier]")

    load_more(view)
    assert listed(view, items) == ~w(a b c d e f g h i j)
    refute more?(view)
  end

  test "opened at a later page reads the page after it", %{items: items} do
    view = open("/offset?page=2")
    assert listed(view, items) == ~w(e f g h)

    load_more(view)
    assert listed(view, items) == ~w(e f g h i j)
    refute more?(view)
  end
end
