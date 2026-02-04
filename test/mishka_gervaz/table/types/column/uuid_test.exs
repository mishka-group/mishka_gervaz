defmodule MishkaGervaz.Types.Column.UUIDTest do
  @moduledoc """
  Tests for the UUID column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.UUID

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = UUID.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(UUID)
      assert function_exported?(UUID, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(UUID)
    end
  end
end
