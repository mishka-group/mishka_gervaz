defmodule MishkaGervaz.Table.Templates.PaginationRowTest do
  @moduledoc """
  Every pager is one row of three parts, in order: the page size selector first, Load More or the
  page buttons in the middle, and last where the reader is in the list. A `:load_more` or
  `:infinite` list says which rows it shows of its total (`Shared.range_label/1`), a numbered one
  which page of how many.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  @parts ~w(gervaz-pagination-leading gervaz-pagination-center gervaz-pagination-trailing)

  defp state(updates) do
    "posts"
    |> State.init(ComplexTestResource, %{id: "user-1", role: :admin})
    |> State.update([loading: :loaded, has_initial_data?: true] ++ updates)
  end

  defp render_pagination(state, type) do
    render_component(&Shared.render_pagination/1, %{
      static: state.static,
      state: state,
      pagination_type: type,
      myself: nil,
      __changed__: %{}
    })
  end

  defp parts(html) do
    doc = LazyHTML.from_fragment(html)
    assert doc |> LazyHTML.query("[data-role='gervaz-pagination']") |> Enum.count() == 1

    doc
    |> LazyHTML.query("[data-role='gervaz-pagination'] > [data-role]")
    |> Enum.map(&{&1 |> LazyHTML.attribute("data-role") |> hd(), &1})
  end

  defp text(part), do: part |> LazyHTML.text() |> String.trim()

  defp has?(part, selector), do: part |> LazyHTML.query(selector) |> Enum.count() > 0

  describe "a Load more list" do
    test "puts the page size selector, Load More and the rows shown on one row, in order" do
      parts =
        [page: 1, has_more?: true, total_count: 50, next_offset: 20]
        |> state()
        |> render_pagination(:load_more)
        |> parts()

      assert Enum.map(parts, &elem(&1, 0)) == @parts
      [{_, leading}, {_, center}, {_, trailing}] = parts

      assert has?(leading, "select[name='size']")
      assert has?(center, "button[phx-click='load_more']")
      assert text(center) == "Load More Posts"
      assert text(trailing) == "Showing 1–20 of 50"
    end

    test "keeps the three parts once every row is shown, with no Load More" do
      [{_, _}, {_, center}, {_, trailing}] =
        [page: 3, has_more?: false, total_count: 50, next_offset: 50]
        |> state()
        |> render_pagination(:load_more)
        |> parts()

      refute has?(center, "button")
      assert text(trailing) == "Showing 1–50 of 50"
    end

    test "draws no Load More while a page loads" do
      [{_, _}, {_, center}, {_, _}] =
        [page: 1, has_more?: true, total_count: 50, next_offset: 20]
        |> state()
        |> State.update(loading: :loading, loading_type: :more)
        |> render_pagination(:load_more)
        |> parts()

      refute has?(center, "button[phx-click='load_more']")
    end
  end

  describe "an infinite list" do
    test "has no button in the middle and counts the rows shown" do
      [{_, leading}, {_, center}, {_, trailing}] =
        [page: 2, has_more?: true, total_count: 50, next_offset: 40]
        |> state()
        |> render_pagination(:infinite)
        |> parts()

      assert has?(leading, "select[name='size']")
      refute has?(center, "button")
      assert text(trailing) == "Showing 1–40 of 50"
    end
  end

  describe "a numbered list" do
    test "puts the page size selector, the page buttons and the page info on one row, in order" do
      parts =
        [page: 2, total_pages: 3, total_count: 50]
        |> state()
        |> render_pagination(:numbered)
        |> parts()

      assert Enum.map(parts, &elem(&1, 0)) == @parts
      [{_, leading}, {_, center}, {_, trailing}] = parts

      assert has?(leading, "select[name='size']")
      assert has?(center, "button[phx-click='prev_page']")
      assert has?(center, "button[phx-click='go_to_page'][phx-value-page='3']")
      assert has?(center, "button[phx-click='next_page']")
      assert text(trailing) == "Page 2 of 3"
    end
  end

  describe "range_label/1" do
    test "grows with each page Load more brings" do
      assert Shared.range_label(state(page: 1, total_count: 136, next_offset: 20)) ==
               "Showing 1–20 of 136"

      assert Shared.range_label(state(page: 2, total_count: 136, next_offset: 40)) ==
               "Showing 1–40 of 136"
    end

    test "ends at the last row, not at the end of the last page" do
      assert Shared.range_label(state(page: 3, total_count: 48, next_offset: 48)) ==
               "Showing 1–48 of 48"
    end

    test "starts at the first row shown on a list opened past its first page" do
      opened = state(page: 3, first_page: 3, total_count: 136, next_offset: 60)
      assert Shared.range_label(opened) == "Showing 41–60 of 136"

      assert Shared.range_label(%{opened | first_page: 2}) == "Showing 21–60 of 136"
    end

    test "leaves out the rows the view took out of the list" do
      assert Shared.range_label(state(page: 2, total_count: 73, next_offset: 38)) ==
               "Showing 1–38 of 73"
    end

    test "counts the page slots before a load sets where the rows end" do
      assert Shared.range_label(state(page: 2, total_count: 73, next_offset: 0)) ==
               "Showing 1–40 of 73"
    end

    test "counts no rows on a page past the last" do
      past =
        state(
          page: 999,
          first_page: 999,
          total_count: 136,
          next_offset: 0,
          records_result: Phoenix.LiveView.AsyncResult.ok(%{page: 999, empty?: true})
        )

      assert Shared.range_label(past) == "Showing 0 of 136"
    end

    test "says nothing for a list with no rows or a table that keeps no count" do
      assert Shared.range_label(state(page: 1, total_count: 0)) == nil

      counted = state(page: 1, total_count: 50, next_offset: 20)
      ui = %{counted.static.pagination_ui | show_total: false}
      uncounted = %{counted | static: %{counted.static | pagination_ui: ui}}

      assert Shared.range_label(uncounted) == nil

      [{_, _}, {_, _}, {_, trailing}] =
        uncounted |> State.update(has_more?: true) |> render_pagination(:load_more) |> parts()

      assert text(trailing) == ""
    end
  end
end
