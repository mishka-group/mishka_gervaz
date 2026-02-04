defmodule MishkaGervaz.Types.Filter.TextTest do
  @moduledoc """
  Tests for the Text filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Text
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Text.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Text.parse_value("", %{}) == nil
    end

    test "returns trimmed string for string value" do
      assert Text.parse_value("  hello  ", %{}) == "hello"
    end

    test "returns value as-is for other types" do
      assert Text.parse_value(123, %{}) == 123
    end
  end

  describe "build_query/3 single field" do
    test "returns query unchanged for nil value" do
      query = Ash.Query.new(Post)
      result = Text.build_query(query, :title, nil)
      assert result == query
    end

    test "returns query unchanged for empty string" do
      query = Ash.Query.new(Post)
      result = Text.build_query(query, :title, "")
      assert result == query
    end

    test "applies contains filter for string value" do
      query = Ash.Query.new(Post)
      result = Text.build_query(query, :title, "hello")
      assert result != query
    end
  end

  describe "build_query/4 multi-field" do
    test "applies OR filter across multiple fields" do
      query = Ash.Query.new(Post)
      filter = %{fields: [:title, :content]}
      result = Text.build_query(query, :search, "test", filter)
      assert result != query
    end

    test "falls back to single-field search for empty fields list" do
      query = Ash.Query.new(Post)
      filter = %{fields: []}
      result = Text.build_query(query, :search, "test", filter)
      # With empty fields, falls through to single-field build_query which applies filter
      assert result != query
    end

    test "returns query unchanged for nil value with fields" do
      query = Ash.Query.new(Post)
      filter = %{fields: [:title, :content]}
      result = Text.build_query(query, :search, nil, filter)
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Text.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end
