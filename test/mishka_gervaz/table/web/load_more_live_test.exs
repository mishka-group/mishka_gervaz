defmodule MishkaGervaz.Table.Web.LoadMoreLiveTest do
  @moduledoc """
  Load more on a table that keeps no rows it has loaded, so its rows live only in the stream,
  driven the way a reader drives it while other views change rows over realtime.

  A realtime notification reaches the table in two hand-offs: the page passes it on with
  `send_update`, and the table reads a burst of them in one message it sends itself. `settle/1`
  waits for both, then for any task the read started, before the test looks.

  Load more reads after the rows the view shows, so a row another view removed moves no row past
  it, and a row drawn again is drawn once, in its place.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlainItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @titles ~w(a b c d e f g h i j)

  setup do
    on_exit(fn -> PlainItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{items: Enum.map(@titles, &Ash.create!(PlainItem, %{title: &1}))}
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
    titles = Map.new(items, &{"items_plain_items-#{&1.id}", &1.title})

    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#items [id^='items_plain_items-']")
    |> LazyHTML.attribute("id")
    |> Enum.flat_map(&List.wrap(titles[&1]))
  end

  defp notify(view, action_name, records) do
    for record <- List.wrap(records) do
      notification = %Ash.Notifier.Notification{
        resource: PlainItem,
        action: Ash.Resource.Info.action(PlainItem, action_name),
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

  defp wipe(view) do
    view
    |> element(~s|#items [phx-click="bulk_action"][phx-value-action="wipe"]|)
    |> render_click()

    render_async(view, @await)
  end

  describe "after rows another view removed" do
    test "passes no row", %{items: [a, b | _] = items} do
      other = open("/plain")
      view = open("/plain")

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
      view = open("/plain")
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

  describe "after a row created elsewhere is drawn first" do
    test "draws a row it shows once, in its place, and passes no row", %{items: items} do
      view = open("/plain")
      aa = Ash.create!(PlainItem, %{title: "aa"})
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
      view = open("/plain")
      z = Ash.create!(PlainItem, %{title: "z"})
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
    view = open("/plain")
    b2 = Ash.update!(b, %{title: "b2"})
    items = Enum.map(items, &if(&1.id == b.id, do: b2, else: &1))

    notify(view, :update, b2)
    assert listed(view, items) == ~w(a b2 c d)

    load_more(view)
    assert listed(view, items) == ~w(a b2 c d e f g h)
  end

  test "after its own bulk destroy, passes no row", %{items: [a, b | _] = items} do
    view = open("/plain")

    pick(view, a)
    pick(view, b)
    wipe(view)
    assert listed(view, items) == ~w(c d e f)

    load_more(view)
    assert listed(view, items) == ~w(c d e f g h i j)
    refute more?(view)
  end

  test "opened at a later page reads the page after it", %{items: items} do
    view = open("/plain?page=2")
    assert listed(view, items) == ~w(e f g h)

    load_more(view)
    assert listed(view, items) == ~w(e f g h i j)
    refute more?(view)
  end
end
