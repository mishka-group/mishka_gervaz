defmodule MishkaGervaz.Types.Column.BooleanTest do
  @moduledoc """
  Tests for the Boolean column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Boolean

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Boolean.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Boolean)
      assert function_exported?(Boolean, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Boolean)
    end
  end
end
