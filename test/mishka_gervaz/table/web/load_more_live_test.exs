defmodule MishkaGervaz.Table.Web.LoadMoreLiveTest do
  @moduledoc """
  Load more on a table that keeps no rows it has loaded, so its rows live only in the stream,
  driven the way a reader drives it while other views change rows over realtime.

  A realtime notification reaches the table in two hand-offs: the page passes it on with
  `send_update`, and the table reads a burst of them in one message it sends itself. `settle/1`
  waits for both, then for any task the read started, before the test looks.

  Its read allows keyset pagination, so Load more reads the page after the last row's keyset: a row
  another view removed or added, shown or not, or one the view deleted itself or with a custom
  action, moves no row past it and takes no row from the page, and a row drawn again is drawn once,
  in its place. A read without keyset, or a keyset Ash refuses, reads from the offset of the rows
  shown instead (`MishkaGervaz.Table.Web.LoadMoreOffsetLiveTest`).

  Opened past its first page, as a reload after Load more opens it, the table shows that page alone,
  and Load earlier reads the page before the first row shown, by its keyset, and puts it above.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Web.{DataLoader, State}
  alias MishkaGervaz.Table.Web.DataLoader.PaginationHandler
  alias MishkaGervaz.Test.Queries
  alias MishkaGervaz.Test.Web.{FeedItem, KeptItem, PlainItem}

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

    test "that it did not show, still adds a full page", %{items: items} do
      view = open("/plain")
      h = Enum.find(items, &(&1.title == "h"))

      Ash.destroy!(h)
      notify(view, :destroy, h)
      assert listed(view, items) == ~w(a b c d)

      load_more(view)
      assert listed(view, items) == ~w(a b c d e f g i)

      load_more(view)
      assert listed(view, items) == ~w(a b c d e f g i j)
      refute more?(view)
    end

    test "reads one page in one read", %{items: [a, b | _] = items} do
      view = open("/plain")
      Enum.each([a, b], &Ash.destroy!/1)
      notify(view, :destroy, [a, b])

      {_view, queries} = Queries.count(fn -> load_more(view) end)

      assert queries == 1
      assert listed(view, items) == ~w(c d e f g h)
    end
  end

  describe "after a row it deletes itself" do
    test "passes no row with realtime off", %{items: [_a, b | _] = items} do
      view = open("/plain")

      delete_row(view, b)
      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f g h)
    end

    test "passes no row when a custom action removed it", %{items: [_a, b | _] = items} do
      view = open("/plain")

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
      view = open("/plain")

      delete_row(view, b)
      notify(view, :destroy, b)
      assert listed(view, items) == ~w(a c d)

      load_more(view)
      assert listed(view, items) == ~w(a c d e f g h)
    end
  end

  describe "after a row created elsewhere is drawn first" do
    test "adds a full page and passes no row", %{items: items} do
      view = open("/plain")
      aa = Ash.create!(PlainItem, %{title: "aa"})
      items = [aa | items]

      notify(view, :create, aa)
      assert listed(view, items) == ~w(aa a b c d)

      load_more(view)
      assert listed(view, items) == ~w(aa a b c d e f g h)

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

  describe "opened past its first page" do
    defp earlier?(view), do: has_element?(view, "#items button[phx-click=load_earlier]")

    defp load_earlier(view) do
      view |> element("#items button[phx-click=load_earlier]") |> render_click()
      render_async(view, @await)
    end

    test "shows that page alone, and Load earlier brings the pages before it one at a time", %{
      items: items
    } do
      view = open("/plain?page=3")
      assert listed(view, items) == ~w(i j)
      assert earlier?(view)

      load_earlier(view)
      assert listed(view, items) == ~w(e f g h i j)
      assert earlier?(view)

      load_earlier(view)
      assert listed(view, items) == ~w(a b c d e f g h i j)
      refute earlier?(view)
    end

    test "Load more still goes on after the last row", %{items: items} do
      view = open("/plain?page=2")
      load_earlier(view)
      assert listed(view, items) == ~w(a b c d e f g h)
      assert more?(view)

      load_more(view)
      assert listed(view, items) == ~w(a b c d e f g h i j)
      refute more?(view)
      refute earlier?(view)
    end

    test "after a row before it was removed elsewhere, still brings a full page", %{
      items: [_a, _b, c | _] = items
    } do
      view = open("/plain?page=3")
      Ash.destroy!(c)

      load_earlier(view)
      assert listed(view, items) == ~w(e f g h i j)

      load_earlier(view)
      assert listed(view, items) == ~w(a b d e f g h i j)
      refute earlier?(view)
    end

    test "reads one page in one read", %{items: items} do
      view = open("/plain?page=3")

      {_view, queries} = Queries.count(fn -> load_earlier(view) end)

      assert queries == 1
      assert listed(view, items) == ~w(e f g h i j)
    end

    test "a page past the last offers no Load earlier" do
      view = open("/plain?page=9")
      refute earlier?(view)
    end

    test "the footer says which rows it shows as Load earlier and Load more bring pages" do
      view = open("/plain?page=2")
      assert shown(view) == "Showing 5–8 of 10"

      load_earlier(view)
      assert shown(view) == "Showing 1–8 of 10"

      load_more(view)
      assert shown(view) == "Showing 1–10 of 10"
    end
  end

  test "the footer grows its range with each Load more" do
    view = open("/plain")
    assert shown(view) == "Showing 1–4 of 10"

    load_more(view)
    assert shown(view) == "Showing 1–8 of 10"
  end

  defp shown(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#items [data-role='gervaz-pagination-trailing']")
    |> LazyHTML.text()
    |> String.trim()
  end

  describe "the read Load more and Load earlier make" do
    defp more_state(resource, page_size, updates) do
      "items"
      |> State.init(resource, %{id: "master-1", site_id: nil, role: :admin})
      |> State.update([current_page_size: page_size, loading_type: :more] ++ updates)
    end

    defp no_kept_rows(state), do: %{state | static: %{state.static | keep_loaded_records: false}}

    defp read_titles(state, page) do
      {^page, result, false, _info} =
        PaginationHandler.Default.load_page(
          state,
          DataLoader.read_query(state),
          page,
          :master_read,
          nil
        )

      Enum.map(result.results, & &1.title)
    end

    defp created(resource, titles) do
      on_exit(fn -> resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
      Enum.map(titles, &Ash.create!(resource, %{title: &1}))
    end

    defp keyset_of(resource, title) do
      resource
      |> Ash.Query.sort(title: :asc)
      |> Ash.read!(page: [limit: 10])
      |> Map.fetch!(:results)
      |> Enum.find(&(&1.title == title))
      |> then(& &1.__metadata__[:keyset])
    end

    test "reads after the keyset of the last row when the action allows keyset" do
      state = more_state(PlainItem, 4, after_keyset: keyset_of(PlainItem, "b"))
      assert read_titles(state, 2) == ~w(c d e f)
    end

    test "reads from the offset of the rows shown when Ash refuses the keyset" do
      state = more_state(PlainItem, 4, after_keyset: "not-a-keyset", next_offset: 3)
      assert read_titles(state, 2) == ~w(d e f g)
    end

    test "reads from the offset of the rows shown when the action has no keyset pagination" do
      created(FeedItem, ~w(a b c d e))
      refute Ash.Resource.Info.action(FeedItem, :master_read).pagination.keyset?

      state =
        more_state(FeedItem, 2,
          after_keyset: keyset_of(FeedItem, "a"),
          next_offset: 1,
          sort_fields: [title: :asc]
        )

      assert read_titles(state, 2) == ~w(b c)
    end

    test "on a table that keeps its rows, reads after them when no keyset is known" do
      [a, b | _] = created(KeptItem, ~w(a b c d e))

      state = more_state(KeptItem, 2, loaded_records: [a, b], after_keyset: nil)
      assert read_titles(state, 2) == ~w(c d)
    end

    test "fills a page larger than the read's max_page_size after the keyset" do
      created(KeptItem, ~w(a b c d e f g h))

      state = more_state(KeptItem, 5, after_keyset: keyset_of(KeptItem, "b")) |> no_kept_rows()
      assert read_titles(state, 2) == ~w(c d e f g)
    end

    test "Load earlier reads before the keyset of the first row when the action allows keyset" do
      state =
        more_state(PlainItem, 2, loading_type: :earlier, before_keyset: keyset_of(PlainItem, "e"))

      assert read_titles(state, 1) == ~w(c d)
    end

    test "Load earlier fills a page larger than the read's max_page_size before the keyset" do
      created(KeptItem, ~w(a b c d e f g h))

      state =
        KeptItem
        |> more_state(5, loading_type: :earlier, before_keyset: keyset_of(KeptItem, "h"))
        |> no_kept_rows()

      assert read_titles(state, 1) == ~w(c d e f g)
    end

    test "Load earlier reads the page's offset when the action has no keyset pagination" do
      created(FeedItem, ~w(a b c d e))

      state =
        more_state(FeedItem, 2,
          loading_type: :earlier,
          before_keyset: keyset_of(FeedItem, "e"),
          sort_fields: [title: :asc]
        )

      assert read_titles(state, 1) == ~w(a b)
    end
  end

  test "opened at a later page reads the page after it", %{items: items} do
    view = open("/plain?page=2")
    assert listed(view, items) == ~w(e f g h)

    load_more(view)
    assert listed(view, items) == ~w(e f g h i j)
    refute more?(view)
  end
end
