defmodule MishkaGervaz.Table.Types.Action.UnarchiveTest do
  @moduledoc """
  Tests for the Unarchive action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Unarchive

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Unarchive.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Unarchive)
      assert function_exported?(Unarchive, :render, 5)
    end
  end

  describe "registry" do
    test "registered in Types.Action under :unarchive" do
      assert MishkaGervaz.Table.Types.Action.get(:unarchive) == Unarchive
    end
  end
end
