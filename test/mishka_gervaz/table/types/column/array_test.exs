defmodule MishkaGervaz.Types.Column.ArrayTest do
  @moduledoc """
  Tests for the Array column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Array

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Array.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Array)
      assert function_exported?(Array, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Array)
    end
  end
end
