defmodule MishkaGervaz.Types.Action.EditTest do
  @moduledoc """
  Tests for the Edit action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Edit

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Edit.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Edit)
      assert function_exported?(Edit, :render, 5)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Edit)
    end
  end

  describe "type registry" do
    test "edit type is registered in action type registry" do
      module = MishkaGervaz.Table.Types.Action.get_or_passthrough(:edit)
      assert module == MishkaGervaz.Table.Types.Action.Edit
    end

    test "edit type is in builtin types list" do
      types = MishkaGervaz.Table.Types.Action.builtin_types()
      assert :edit in types
    end
  end
end
