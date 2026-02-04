defmodule MishkaGervaz.Types.Action.LinkTest do
  @moduledoc """
  Tests for the Link action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Link

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Link.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Link)
      assert function_exported?(Link, :render, 5)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Link)
    end
  end
end
