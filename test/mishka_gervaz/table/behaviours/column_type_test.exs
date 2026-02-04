defmodule MishkaGervaz.Behaviours.ColumnTypeTest do
  @moduledoc """
  Tests for the ColumnType behaviour.
  """
  use ExUnit.Case, async: true

  describe "behaviour callbacks" do
    test "defines required render callback" do
      callbacks = MishkaGervaz.Table.Behaviours.ColumnType.behaviour_info(:callbacks)

      assert {:render, 4} in callbacks
    end

    test "defines optional callbacks" do
      optional = MishkaGervaz.Table.Behaviours.ColumnType.behaviour_info(:optional_callbacks)

      assert {:cell_class, 1} in optional
    end
  end
end
