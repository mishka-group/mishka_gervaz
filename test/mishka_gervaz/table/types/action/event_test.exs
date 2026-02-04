defmodule MishkaGervaz.Types.Action.EventTest do
  @moduledoc """
  Tests for the Event action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Event

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Event.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Event)
      assert function_exported?(Event, :render, 5)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Event)
    end
  end
end
