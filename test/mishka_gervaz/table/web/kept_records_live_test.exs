defmodule MishkaGervaz.Table.Web.KeptRecordsLiveTest do
  @moduledoc """
  A table that keeps the rows it has loaded (`keep_loaded_records`), driven the way a reader
  drives it, in the stock `MishkaGervaz.Table.Templates.Table` and in
  `MishkaGervaz.Test.Web.KeptRows`, a template drawn from those kept rows.

  A realtime notification reaches the table in two hand-offs: the page passes it on with
  `send_update`, and the table reads a burst of them in one message it sends itself. `settle/1`
  waits for both, then for any task the read started, before the test looks.

  Load more reads only the page after the rows the table keeps and adds it to them, page after
  page, past the most rows the resource's read takes at once (`max_page_size`), until the last row;
  a row taken out of the kept rows moves no row past the next Load more. A page larger than that
  holds every row it asks for on a table that keeps no rows too. A bulk action whose rows leave the
  list takes them out of the kept rows and reads none; any other bulk action reloads every page
  loaded before it.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Web.{DataLoader, State}
  alias MishkaGervaz.Table.Web.DataLoader.PaginationHandler
  alias MishkaGervaz.Test.Queries
  alias MishkaGervaz.Test.Web.KeptItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @titles ~w(a b c d e f g)

  setup do
    on_exit(fn -> KeptItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    %{items: Enum.map(@titles, &Ash.create!(KeptItem, %{title: &1}))}
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

  defp kept(view),
    do:
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(~s|#items [data-role="kept-row"]|)
      |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  defp listed(view, items) do
    html = render(view)

    items
    |> Enum.filter(&has_element?(view, "#items_kept_items-#{&1.id}"))
    |> Enum.sort_by(&(:binary.match(html, "items_kept_items-#{&1.id}") |> elem(0)))
    |> Enum.map(& &1.title)
  end

  defp notification(action_name, record) do
    %Ash.Notifier.Notification{
      resource: KeptItem,
      action: Ash.Resource.Info.action(KeptItem, action_name),
      data: record
    }
  end

  defp notify(view, action_name, record) do
    send(view.pid, {:notify, notification(action_name, record)})
    settle(view)
  end

  defp settle(view) do
    render(view)
    render(view)
    render_async(view, @await)
  end

  defp retitle!(item, title), do: Ash.update!(item, %{title: title})

  defp pick(view, item) do
    view
    |> element(~s|#items [phx-click="toggle_select"][phx-value-id="#{item.id}"]|)
    |> render_click()
  end

  defp bulk(view, action) do
    view
    |> element(~s|#items [phx-click="bulk_action"][phx-value-action="#{action}"]|)
    |> render_click()

    render_async(view, @await)
  end

  defp delete_row(view, item) do
    view
    |> element(~s|#items [phx-click="delete"][phx-value-id="#{item.id}"]|)
    |> render_click()
  end

  defp in_order?(kept, titles), do: kept == Enum.take(titles, length(kept))

  describe "a realtime update of a row the table shows" do
    test "draws it again in its place, in the rows the table keeps", %{items: [a, b | _]} do
      view = open("/kept?template=kept_rows")
      load_more(view)

      notify(view, :update, retitle!(b, "b2"))
      assert kept(view) == ~w(a b2 c d)

      notify(view, :update, retitle!(a, "a2"))
      assert kept(view) == ~w(a2 b2 c d)
    end

    test "draws it again in its place in the stock table", %{items: [a, b | _] = items} do
      view = open("/kept?template=table")
      load_more(view)

      notify(view, :update, retitle!(b, "b2"))
      assert render(view) =~ "b2"
      assert listed(view, Enum.map(items, &Ash.get!(KeptItem, &1.id))) == ~w(a b2 c d)

      notify(view, :update, retitle!(a, "a2"))
      assert listed(view, Enum.map(items, &Ash.get!(KeptItem, &1.id))) == ~w(a2 b2 c d)
    end
  end

  describe "a burst of realtime updates" do
    test "is read once, and draws every row it changed", %{items: [a, b, c | _]} do
      view = open("/kept?template=kept_rows")
      load_more(view)

      {_view, queries} =
        Queries.count(fn ->
          :sys.suspend(view.pid)

          for {item, title} <- [{a, "a2"}, {b, "b2"}, {c, "c2"}] do
            send(view.pid, {:notify, notification(:update, retitle!(item, title))})
          end

          :sys.resume(view.pid)
          settle(view)
        end)

      assert kept(view) == ~w(a2 b2 c2 d)
      assert queries == 2, "one read of the rows and one count of the total"
    end
  end

  describe "the rows the table keeps follow realtime" do
    test "a row destroyed elsewhere leaves them", %{items: [_a, b | _]} do
      view = open("/kept?template=kept_rows")

      Ash.destroy!(b)
      notify(view, :destroy, b)

      assert kept(view) == ~w(a)
    end

    test "a row created elsewhere is drawn first, as the stock table draws it" do
      view = open("/kept?template=kept_rows")

      notify(view, :create, Ash.create!(KeptItem, %{title: "new"}))

      assert kept(view) == ~w(new a b)
    end
  end

  describe "a bulk action" do
    test "whose rows leave the list takes them out of the rows kept", %{
      items: [_a, b | _] = items
    } do
      view = open("/kept?template=table")
      load_more(view)
      load_more(view)

      pick(view, b)
      bulk(view, :wipe)

      assert listed(view, items) == ~w(a c d e f)
      assert more?(view)
    end

    test "whose rows leave the list reads no row, however many pages are loaded", %{
      items: [a, b | _] = items
    } do
      one_page = open("/kept?template=table")
      pick(one_page, a)
      {_view, on_one_page} = Queries.count(fn -> bulk(one_page, :wipe) end)

      three_pages = open("/kept?template=table")
      for _page <- 1..2, do: load_more(three_pages)
      pick(three_pages, b)
      {_view, on_three_pages} = Queries.count(fn -> bulk(three_pages, :wipe) end)

      assert on_three_pages == on_one_page
      assert listed(three_pages, items) == ~w(c d e f g)
    end

    test "after it, Load more goes on from the rows kept and passes no row", %{
      items: [_a, b | _] = items
    } do
      view = open("/kept?template=table")
      load_more(view)

      pick(view, b)
      bulk(view, :wipe)
      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f g)
      refute more?(view)
    end

    test "that changes rows reloads every page loaded before it, so the rows loaded stay", %{
      items: [_a, b | _] = items
    } do
      view = open("/kept?template=table")
      load_more(view)

      pick(view, b)
      bulk(view, :finish)

      assert listed(view, items) == ~w(a b c d)
      assert Ash.get!(KeptItem, b.id).done
    end
  end

  describe "load more" do
    test "keeps every row loaded before, past the most rows the read takes at once" do
      view = open("/kept?template=kept_rows")
      assert kept(view) == ~w(a b)

      load_more(view)
      assert kept(view) == ~w(a b c d)

      load_more(view)
      assert kept(view) == ~w(a b c d e f)
      assert more?(view)

      load_more(view)
      assert kept(view) == @titles
      refute more?(view)
    end

    test "lists every row loaded so far in the stock table too", %{items: items} do
      view = open("/kept?template=table")

      for _page <- 1..3, do: load_more(view)

      assert listed(view, items) == @titles
      refute more?(view)
    end

    test "reads only the next page, however many pages are kept" do
      view = open("/kept?template=kept_rows")

      queries =
        for _page <- 1..3, do: view |> then(&Queries.count(fn -> load_more(&1) end)) |> elem(1)

      assert kept(view) == @titles
      assert Enum.uniq(queries) == [hd(queries)]
    end

    test "after a row destroyed elsewhere left the rows kept, passes no row", %{
      items: [_a, b | _]
    } do
      view = open("/kept?template=kept_rows")
      load_more(view)

      Ash.destroy!(b)
      notify(view, :destroy, b)
      load_more(view)

      assert in_order?(kept(view), ~w(a c d e f g))
      assert kept(view) == ~w(a c d e f)
    end

    test "after a row deleted in the view left the rows kept, passes no row", %{
      items: [_a, b | _] = items
    } do
      view = open("/kept?template=table")
      load_more(view)

      delete_row(view, b)
      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f)
    end

    test "opened at a later page reads every page up to it" do
      view = open("/kept?template=kept_rows&page=3")

      assert kept(view) == ~w(a b c d e f)
      assert more?(view)
    end

    test "opened at a later page offers no Load earlier, since it shows the first page", %{
      items: items
    } do
      view = open("/kept?template=table&page=2")

      assert listed(view, items) == ~w(a b c d)
      refute has_element?(view, "#items button[phx-click=load_earlier]")
    end
  end

  test "a page larger than the read's max_page_size holds every row it asks for" do
    state =
      "items"
      |> State.init(KeptItem, %{id: "master-1", site_id: nil, role: :admin})
      |> State.update(current_page_size: 5)
      |> then(&%{&1 | static: %{&1.static | keep_loaded_records: false}})

    page = fn number ->
      {^number, result, _reset?, _info} =
        PaginationHandler.Default.load_page(
          state,
          DataLoader.read_query(state),
          number,
          :master_read,
          nil
        )

      {Enum.map(result.results, & &1.title), result.more?}
    end

    assert page.(1) == {~w(a b c d e), true}
    assert page.(2) == {~w(f g), false}
  end
end
