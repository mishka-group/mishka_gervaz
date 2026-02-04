defmodule MishkaGervaz.DSL.RowTest do
  @moduledoc """
  Tests for the row DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, ComplexTestResource}

  describe "row configuration" do
    test "row config is present" do
      config = ResourceInfo.table_config(Post)
      assert config.row != nil
    end

    test "selectable key is configured" do
      config = ResourceInfo.table_config(Post)
      assert config.row.selectable == true
    end

    test "event key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.row.event == "show"
    end
  end

  describe "row class nested section" do
    test "class possible key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.row.class.possible == ["bg-yellow-50", "bg-red-50", "bg-green-50"]
    end

    test "class apply key is a function" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.row.class.apply, 1)
    end

    test "class apply function returns correct class for archived record" do
      config = ResourceInfo.table_config(ComplexTestResource)
      record = %{status: :archived, is_featured: false}
      result = config.row.class.apply.(record)
      assert result == "bg-red-50"
    end

    test "class apply function returns correct class for featured record" do
      config = ResourceInfo.table_config(ComplexTestResource)
      record = %{status: :published, is_featured: true}
      result = config.row.class.apply.(record)
      assert result == "bg-yellow-50"
    end

    test "class apply function returns nil for regular record" do
      config = ResourceInfo.table_config(ComplexTestResource)
      record = %{status: :published, is_featured: false}
      result = config.row.class.apply.(record)
      assert result == nil
    end
  end

  describe "row DSL defaults" do
    test "selectable defaults to false in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Row.schema()
      selectable_config = Keyword.get(schema, :selectable)
      assert Keyword.get(selectable_config, :default) == false
    end
  end

  describe "row has expected structure" do
    test "row is a map with expected keys" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.row)
      assert Map.has_key?(config.row, :event)
      assert Map.has_key?(config.row, :selectable)
      assert Map.has_key?(config.row, :class)
    end

    test "row class is a map with expected keys" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.row.class)
      assert Map.has_key?(config.row.class, :possible)
      assert Map.has_key?(config.row.class, :apply)
    end
  end
end
