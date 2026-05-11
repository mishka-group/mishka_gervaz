defmodule MishkaGervaz.Table.Types.Action.PermanentDestroyTest do
  @moduledoc """
  Tests for the PermanentDestroy action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.PermanentDestroy

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = PermanentDestroy.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(PermanentDestroy)
      assert function_exported?(PermanentDestroy, :render, 5)
    end
  end

  describe "registry" do
    test "registered in Types.Action under :permanent_destroy" do
      assert MishkaGervaz.Table.Types.Action.get(:permanent_destroy) == PermanentDestroy
    end
  end
end
