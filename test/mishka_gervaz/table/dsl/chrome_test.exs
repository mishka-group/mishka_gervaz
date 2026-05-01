defmodule MishkaGervaz.Table.DSL.ChromeTest do
  @moduledoc """
  Tests for the chrome entities (header, footer, notice) inside the table
  layout DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.ChromeTable

  describe "header" do
    test "compiled into layout" do
      assert %{} = TableInfo.header(ChromeTable)
    end

    test "title is set" do
      assert TableInfo.header(ChromeTable).title == "Pages"
    end

    test "description is set" do
      assert TableInfo.header(ChromeTable).description == "All published and draft pages."
    end

    test "icon is set" do
      assert TableInfo.header(ChromeTable).icon == "hero-document-text"
    end

    test "class is set" do
      assert TableInfo.header(ChromeTable).class == "mb-6"
    end

    test "visible defaults to true" do
      assert TableInfo.header(ChromeTable).visible == true
    end

    test "restricted defaults to false" do
      assert TableInfo.header(ChromeTable).restricted == false
    end
  end

  describe "footer" do
    test "compiled into layout" do
      assert %{} = TableInfo.footer(ChromeTable)
    end

    test "content callable returns string" do
      content = TableInfo.footer(ChromeTable).content
      assert is_function(content, 1)
      assert content.(%{}) == "Sorted by priority by default."
    end

    test "class is set" do
      assert TableInfo.footer(ChromeTable).class == "mt-2 text-xs"
    end
  end

  describe "notices/1" do
    test "returns all notices in declaration order" do
      names = ChromeTable |> TableInfo.notices() |> Enum.map(& &1.name)

      assert names == [
               :archived_warning,
               :no_match,
               :bulk_hint,
               :read_only,
               :master_only_top,
               :before_status_col
             ]
    end
  end

  describe "notice properties" do
    test "position atom" do
      assert TableInfo.notice(ChromeTable, :archived_warning).position == :before_table
      assert TableInfo.notice(ChromeTable, :no_match).position == :empty_state
      assert TableInfo.notice(ChromeTable, :bulk_hint).position == :after_bulk_actions
      assert TableInfo.notice(ChromeTable, :read_only).position == :table_top
    end

    test "position tuple {:before_column, :status}" do
      assert TableInfo.notice(ChromeTable, :before_status_col).position ==
               {:before_column, :status}
    end

    test "type" do
      assert TableInfo.notice(ChromeTable, :archived_warning).type == :warning
      assert TableInfo.notice(ChromeTable, :no_match).type == :info
      assert TableInfo.notice(ChromeTable, :bulk_hint).type == :neutral
      assert TableInfo.notice(ChromeTable, :master_only_top).type == :neutral
    end

    test "title and content" do
      n = TableInfo.notice(ChromeTable, :no_match)
      assert n.title == "No records match your filters"
      assert n.content == "Try clearing filters."
    end

    test "icon" do
      assert TableInfo.notice(ChromeTable, :archived_warning).icon == "hero-archive-box"
    end

    test "dismissible defaults to false" do
      assert TableInfo.notice(ChromeTable, :archived_warning).dismissible == false
    end

    test "bind_to is set when declared" do
      assert TableInfo.notice(ChromeTable, :archived_warning).bind_to == :archived_view
      assert TableInfo.notice(ChromeTable, :no_match).bind_to == :no_results
      assert TableInfo.notice(ChromeTable, :bulk_hint).bind_to == :has_selection
    end

    test "bind_to is nil by default" do
      assert TableInfo.notice(ChromeTable, :read_only).bind_to == nil
    end

    test "visible function is preserved" do
      n = TableInfo.notice(ChromeTable, :read_only)
      assert is_function(n.visible, 1)
      assert n.visible.(%{master_user?: false}) == true
      assert n.visible.(%{master_user?: true}) == false
    end

    test "restricted is true for master-only notice" do
      assert TableInfo.notice(ChromeTable, :master_only_top).restricted == true
    end
  end

  describe "notices_at/2" do
    test "filters by atom position" do
      names =
        ChromeTable
        |> TableInfo.notices_at(:table_top)
        |> Enum.map(& &1.name)

      assert names == [:read_only, :master_only_top]
    end

    test "filters by single-match position" do
      assert [%{name: :no_match}] = TableInfo.notices_at(ChromeTable, :empty_state)
    end

    test "filters by tuple position" do
      assert [%{name: :before_status_col}] =
               TableInfo.notices_at(ChromeTable, {:before_column, :status})
    end

    test "returns empty list for unknown position" do
      assert TableInfo.notices_at(ChromeTable, :after_pagination) == []
    end
  end

  describe "Notice.validate_position/1" do
    alias MishkaGervaz.Table.Entities.Notice

    test "accepts valid atom positions" do
      for atom <- Notice.valid_position_atoms() do
        assert Notice.validate_position(atom) == :ok
      end
    end

    test "accepts {:before_column, atom}" do
      assert Notice.validate_position({:before_column, :status}) == :ok
    end

    test "accepts {:after_column, atom}" do
      assert Notice.validate_position({:after_column, :name}) == :ok
    end

    test "rejects unknown atom" do
      assert {:error, _} = Notice.validate_position(:nope)
    end

    test "rejects malformed tuple" do
      assert {:error, _} = Notice.validate_position({:before_column, "string"})
      assert {:error, _} = Notice.validate_position({:wrong, :name})
    end
  end
end
