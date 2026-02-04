defmodule MishkaGervaz.Types.Filter.NumberTest do
  @moduledoc """
  Tests for the Number filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Number
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Number.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Number.parse_value("", %{}) == nil
    end

    test "parses integer string" do
      assert Number.parse_value("42", %{}) == 42.0
    end

    test "parses float string" do
      assert Number.parse_value("3.14", %{}) == 3.14
    end

    test "parses number with trailing text" do
      assert Number.parse_value("42.5px", %{}) == 42.5
    end

    test "returns nil for non-numeric string" do
      assert Number.parse_value("not a number", %{}) == nil
    end

    test "returns integer as-is" do
      assert Number.parse_value(42, %{}) == 42
    end

    test "returns float as-is" do
      assert Number.parse_value(3.14, %{}) == 3.14
    end

    test "returns nil for other types" do
      assert Number.parse_value(%{}, %{}) == nil
      assert Number.parse_value([], %{}) == nil
    end
  end

  describe "build_query/3" do
    test "applies eq filter for integer value" do
      query = Ash.Query.new(Post)
      result = Number.build_query(query, :view_count, 100)
      assert result != query
    end

    test "applies eq filter for float value" do
      query = Ash.Query.new(Post)
      result = Number.build_query(query, :rating, 4.5)
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(Post)
      result = Number.build_query(query, :view_count, nil)
      assert result == query
    end

    test "returns query unchanged for non-number value" do
      query = Ash.Query.new(Post)
      result = Number.build_query(query, :view_count, "100")
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Number.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end
