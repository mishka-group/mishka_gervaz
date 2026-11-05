defmodule MishkaGervaz.Table.Templates.AccordionVisibleTest do
  @moduledoc """
  An `:accordion` row action draws a row's expand caret only where the action is visible, as every
  other row action is drawn: its `visible fn record, state -> boolean end` is asked for each row,
  and `visible false`, `visible :active` / `:archived` and `restricted` are honoured.

  The caret column stays while some row may expand, so a row without a caret keeps the table's
  columns. A table whose accordion no row of this reader can use draws no caret column.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.TranslatedDsl

  @admin %{id: "user-1", site_id: nil, role: :admin}
  @editor %{id: "user-2", site_id: "site-1", role: :editor}

  @records [
    %{id: "row-1", title: "Plain", slug: "plain", status: :published, featured: false},
    %{id: "row-2", title: "Featured", slug: "featured", status: :draft, featured: true},
    %{id: "row-3", title: "Also plain", slug: "also-plain", status: :draft, featured: false}
  ]

  defp table_state(accordion, opts \\ []) do
    state =
      "accordion"
      |> State.init(TranslatedDsl, Keyword.get(opts, :user, @admin))
      |> State.update(
        loading: :loaded,
        has_initial_data?: true,
        archive_status: Keyword.get(opts, :archive_status, :active),
        expanded_id: Keyword.get(opts, :expanded_id)
      )

    row_actions =
      state.static.row_actions ++ [Map.merge(%{name: :expand, type: :accordion}, accordion)]

    %{state | static: %{state.static | row_actions: row_actions}}
  end

  defp render_table(state) do
    stream_name = state.static.stream_name

    render_component(&TableTemplate.render/1, %{
      static: state.static,
      state: state,
      stream: Enum.map(@records, &{"#{stream_name}-#{&1.id}", &1}),
      streams: %{stream_name => []},
      empty?: false,
      failed?: false,
      myself: nil,
      __changed__: %{}
    })
    |> LazyHTML.from_fragment()
  end

  defp carets(html) do
    html
    |> LazyHTML.query(~s|[phx-click="expand_row"]|)
    |> LazyHTML.attribute("phx-value-id")
  end

  defp expanded?(html), do: LazyHTML.query(html, ~s|[phx-click="close_expanded"]|) |> Enum.any?()

  defp tracks(html) do
    html
    |> LazyHTML.query(~s|[style^="grid-template-columns"]|)
    |> LazyHTML.attribute("style")
  end

  describe "visible fn record, state" do
    test "draws a caret only on the rows it answers true for" do
      html = render_table(table_state(%{visible: fn record, _state -> record.featured end}))

      assert carets(html) == ["row-2"]
    end

    test "is asked with the table's state" do
      only_archived = fn _record, state -> state.archive_status == :archived end

      assert carets(render_table(table_state(%{visible: only_archived}))) == []

      assert carets(
               render_table(table_state(%{visible: only_archived}, archive_status: :archived))
             ) ==
               ~w(row-1 row-2 row-3)
    end

    test "keeps the caret column, so a row without a caret keeps the table's columns" do
      hidden = render_table(table_state(%{visible: fn _record, _state -> false end}))
      shown = render_table(table_state(%{visible: fn _record, _state -> true end}))

      assert carets(hidden) == []
      assert tracks(hidden) == tracks(shown)
    end

    test "draws a row the reader expanded closed once its accordion is not visible" do
      state =
        table_state(%{visible: fn record, _state -> record.featured end}, expanded_id: "row-1")

      refute expanded?(render_table(state))
      assert expanded?(render_table(%{state | expanded_id: "row-2"}))
    end
  end

  describe "an accordion no row of this reader can use draws no caret column" do
    test "visible false" do
      html = render_table(table_state(%{visible: false}))
      shown = render_table(table_state(%{}))

      assert carets(html) == []
      assert carets(shown) == ~w(row-1 row-2 row-3)
      refute tracks(html) == tracks(shown)
    end

    test "visible :archived in the active view, and :active in the archived one" do
      assert carets(render_table(table_state(%{visible: :archived}))) == []

      assert carets(render_table(table_state(%{visible: :active}, archive_status: :archived))) ==
               []

      assert carets(render_table(table_state(%{visible: :active}))) == ~w(row-1 row-2 row-3)
    end

    test "restricted, for a reader who is not a master" do
      assert carets(render_table(table_state(%{restricted: true}, user: @editor))) == []
      assert carets(render_table(table_state(%{restricted: true}))) == ~w(row-1 row-2 row-3)
    end
  end
end
