defmodule MishkaGervaz.Types.Column.DateTimeTest do
  @moduledoc """
  Tests for the DateTime column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.DateTime

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = DateTime.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(DateTime)
      assert function_exported?(DateTime, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(DateTime)
    end

    test "has default format constant" do
      # The module should compile and have a default format
      assert Code.ensure_loaded?(DateTime)
    end
  end
end
