defmodule MishkaGervaz.Types.Column.BadgeTest do
  @moduledoc """
  Tests for the Badge column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Badge

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Badge.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Badge)
      assert function_exported?(Badge, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Badge)
    end
  end
end
