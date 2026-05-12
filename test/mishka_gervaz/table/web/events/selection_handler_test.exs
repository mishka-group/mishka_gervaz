defmodule MishkaGervaz.Table.Web.Events.SelectionHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Table.Web.Events.SelectionHandler.Default`.

  Pure state-shape tests: each callback takes and returns a `State` struct,
  no Ash / DB interaction, so we exercise them directly against a minimal
  state fixture rather than going through the LiveComponent.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Events.SelectionHandler.Default, as: Selection
  alias MishkaGervaz.Table.Web.State

  defp blank_state do
    %State{
      static: %State.Static{},
      selected_ids: MapSet.new(),
      excluded_ids: MapSet.new(),
      select_all?: false
    }
  end

  describe "toggle_select/2" do
    test "adds an id to selected_ids when select_all? is false" do
      state = Selection.toggle_select(blank_state(), "a")
      assert MapSet.equal?(state.selected_ids, MapSet.new(["a"]))
      assert MapSet.equal?(state.excluded_ids, MapSet.new())
    end

    test "removes an id already in selected_ids" do
      state = %{blank_state() | selected_ids: MapSet.new(["a", "b"])}
      result = Selection.toggle_select(state, "a")
      assert MapSet.equal?(result.selected_ids, MapSet.new(["b"]))
    end

    test "adds to excluded_ids when select_all? is true" do
      state = %{blank_state() | select_all?: true}
      result = Selection.toggle_select(state, "a")
      assert MapSet.equal?(result.excluded_ids, MapSet.new(["a"]))
    end

    test "removes from excluded_ids when toggling twice" do
      state = %{blank_state() | select_all?: true, excluded_ids: MapSet.new(["a"])}
      result = Selection.toggle_select(state, "a")
      assert MapSet.equal?(result.excluded_ids, MapSet.new())
    end
  end

  describe "toggle_select_all/1" do
    test "flips select_all? false → true and resets sets" do
      state = %{blank_state() | selected_ids: MapSet.new(["x"])}
      result = Selection.toggle_select_all(state)
      assert result.select_all? == true
      assert MapSet.equal?(result.selected_ids, MapSet.new())
      assert MapSet.equal?(result.excluded_ids, MapSet.new())
    end

    test "flips select_all? true → false and resets sets" do
      state = %{blank_state() | select_all?: true, excluded_ids: MapSet.new(["y"])}
      result = Selection.toggle_select_all(state)
      assert result.select_all? == false
      assert MapSet.equal?(result.selected_ids, MapSet.new())
      assert MapSet.equal?(result.excluded_ids, MapSet.new())
    end
  end

  describe "clear_selection/1" do
    test "resets everything regardless of select_all?" do
      state = %{
        blank_state()
        | select_all?: true,
          selected_ids: MapSet.new(["a"]),
          excluded_ids: MapSet.new(["b"])
      }

      result = Selection.clear_selection(state)
      assert result.select_all? == false
      assert MapSet.equal?(result.selected_ids, MapSet.new())
      assert MapSet.equal?(result.excluded_ids, MapSet.new())
    end
  end

  describe "get_selected_ids/1" do
    test "returns the selected_ids list when not select_all" do
      state = %{blank_state() | selected_ids: MapSet.new(["a", "b"])}
      assert Enum.sort(Selection.get_selected_ids(state)) == ["a", "b"]
    end

    test "returns :all when select_all? with no exclusions" do
      state = %{blank_state() | select_all?: true}
      assert Selection.get_selected_ids(state) == :all
    end

    test "returns {:all_except, list} when select_all? with exclusions" do
      state = %{blank_state() | select_all?: true, excluded_ids: MapSet.new(["x", "y"])}
      assert {:all_except, ids} = Selection.get_selected_ids(state)
      assert Enum.sort(ids) == ["x", "y"]
    end
  end
end
