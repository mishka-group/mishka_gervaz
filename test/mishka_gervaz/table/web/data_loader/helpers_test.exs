defmodule MishkaGervaz.Table.Web.DataLoader.HelpersTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Table.Web.DataLoader.Helpers`.

  These pin the sort-list and mode-state primitives that
  `apply_sort/3` and `apply_archive_status/3` depend on. Integration
  tests cover the same paths transitively but a regression here would
  manifest as hard-to-locate ordering / state-restoration bugs.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.DataLoader.Helpers

  describe "toggle_sort_group/3" do
    test "rewrites every entry whose field is in db_fields" do
      sorts = [{:a, :asc}, {:b, :asc}, {:c, :desc}]

      assert Helpers.toggle_sort_group(sorts, [:a, :c], :desc) ==
               [{:a, :desc}, {:b, :asc}, {:c, :desc}]
    end

    test "leaves untouched entries when db_fields is empty" do
      sorts = [{:a, :asc}]
      assert Helpers.toggle_sort_group(sorts, [], :desc) == [{:a, :asc}]
    end

    test "returns [] for empty sorts" do
      assert Helpers.toggle_sort_group([], [:a], :asc) == []
    end
  end

  describe "remove_sort_group/2" do
    test "drops entries whose field is in db_fields" do
      sorts = [{:a, :asc}, {:b, :asc}, {:c, :desc}]
      assert Helpers.remove_sort_group(sorts, [:a, :c]) == [{:b, :asc}]
    end

    test "no-op when db_fields is empty" do
      sorts = [{:a, :asc}, {:b, :desc}]
      assert Helpers.remove_sort_group(sorts, []) == sorts
    end

    test "returns [] for empty sorts" do
      assert Helpers.remove_sort_group([], [:a]) == []
    end
  end

  describe "default_mode_state/0" do
    test "returns the expected shape" do
      state = Helpers.default_mode_state()

      assert state.filter_values == %{}
      assert state.sort_fields == []
      assert state.selected_ids == MapSet.new()
      assert state.excluded_ids == MapSet.new()
      assert state.select_all? == false
    end

    test "is stable across calls (no shared mutable references)" do
      a = Helpers.default_mode_state()
      b = Helpers.default_mode_state()
      assert a == b
      assert a.selected_ids == b.selected_ids
    end
  end
end
