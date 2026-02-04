defmodule MishkaGervaz.Behaviours.FilterTypeTest do
  @moduledoc """
  Tests for the FilterType behaviour.
  """
  use ExUnit.Case, async: true

  describe "behaviour callbacks" do
    test "defines required callbacks" do
      callbacks = MishkaGervaz.Table.Behaviours.FilterType.behaviour_info(:callbacks)

      assert {:render_input, 3} in callbacks
      assert {:parse_value, 2} in callbacks
      assert {:build_query, 3} in callbacks
    end

    test "defines optional callbacks" do
      optional = MishkaGervaz.Table.Behaviours.FilterType.behaviour_info(:optional_callbacks)

      assert {:label, 1} in optional
      assert {:build_query, 4} in optional
    end
  end
end
