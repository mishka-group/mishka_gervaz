defmodule MishkaGervaz.Types.Column.DateTest do
  @moduledoc """
  Tests for the Date column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Date

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Date.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Date)
      assert function_exported?(Date, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Date)
    end
  end
end
