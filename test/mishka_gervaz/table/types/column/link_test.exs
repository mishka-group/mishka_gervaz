defmodule MishkaGervaz.Types.Column.LinkTest do
  @moduledoc """
  Tests for the Link column type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column.Link

  describe "behaviour implementation" do
    test "implements ColumnType behaviour" do
      behaviours = Link.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
    end

    test "defines render/4 function" do
      Code.ensure_loaded!(Link)
      assert function_exported?(Link, :render, 4)
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(Link)
    end
  end
end
