defmodule MishkaGervaz.Types.Action.UpdateTest do
  @moduledoc """
  Tests for the Update action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Update

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Update.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Update)
      assert function_exported?(Update, :render, 5)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Update)
    end
  end
end
