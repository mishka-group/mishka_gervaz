defmodule MishkaGervaz.Table.Web.KeptRecordsLiveTest do
  @moduledoc """
  A table that keeps the rows it has loaded (`keep_loaded_records`), driven the way a reader
  drives it, in the stock `MishkaGervaz.Table.Templates.Table` and in
  `MishkaGervaz.Test.Web.KeptRows`, a template drawn from those kept rows.

  Load more adds the next page to every row loaded before, page after page, past the most rows
  the resource's read takes at once (`max_page_size`), until the last row. A page larger than that
  holds every row it asks for on a table that keeps no rows too.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Web.{DataLoader, State}
  alias MishkaGervaz.Table.Web.DataLoader.PaginationHandler
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
