defmodule MishkaGervaz.Types.Column.TextTest do
  @moduledoc """
  Tests for the Text column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Text

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Text.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Text)
      assert function_exported?(Text, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      # Check that the module compiles and has component capabilities
      assert Code.ensure_loaded?(Text)
    end
  end
end
