defmodule MishkaGervaz.Types.Action.DestroyTest do
  @moduledoc """
  Tests for the Destroy action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Destroy

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Destroy.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Destroy)
      assert function_exported?(Destroy, :render, 5)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Destroy)
    end
  end
end
