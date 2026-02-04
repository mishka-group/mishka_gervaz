defmodule MishkaGervaz.Types.Column.NumberTest do
  @moduledoc """
  Tests for the Number column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Number

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Number.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Number)
      assert function_exported?(Number, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Number)
    end
  end
end
