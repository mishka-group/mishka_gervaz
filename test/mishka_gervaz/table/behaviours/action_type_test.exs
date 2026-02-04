defmodule MishkaGervaz.Behaviours.ActionTypeTest do
  @moduledoc """
  Tests for the ActionType behaviour.
  """
  use ExUnit.Case, async: true

  describe "behaviour callbacks" do
    test "defines required render callback" do
      callbacks = MishkaGervaz.Table.Behaviours.ActionType.behaviour_info(:callbacks)

      assert {:render, 5} in callbacks
    end

    test "has no optional callbacks" do
      optional = MishkaGervaz.Table.Behaviours.ActionType.behaviour_info(:optional_callbacks)

      assert optional == []
    end
  end
end
