defmodule MishkaGervaz.Types.Filter.DateTest do
  @moduledoc """
  Tests for the Date filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Date
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Date.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Date.parse_value("", %{}) == nil
    end

    test "parses valid ISO8601 date string" do
      result = Date.parse_value("2024-01-15", %{})
      assert result == ~D[2024-01-15]
    end

    test "returns nil for invalid date string" do
      assert Date.parse_value("invalid", %{}) == nil
      assert Date.parse_value("2024-13-45", %{}) == nil
    end

    test "returns Date struct as-is" do
      date = ~D[2024-01-15]
      assert Date.parse_value(date, %{}) == date
    end

    test "returns nil for other types" do
      assert Date.parse_value(123, %{}) == nil
      assert Date.parse_value(%{}, %{}) == nil
    end
  end

  describe "build_query/3" do
    test "applies eq filter for Date value" do
      query = Ash.Query.new(Post)
      date = ~D[2024-01-15]
      result = Date.build_query(query, :created_at, date)
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(Post)
      result = Date.build_query(query, :created_at, nil)
      assert result == query
    end

    test "returns query unchanged for non-Date value" do
      query = Ash.Query.new(Post)
      result = Date.build_query(query, :created_at, "2024-01-15")
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Date.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end
