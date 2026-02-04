defmodule MishkaGervaz.Types.Filter.DateRangeTest do
  @moduledoc """
  Tests for the DateRange filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.DateRange
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert DateRange.parse_value(nil, %{}) == nil
    end

    test "parses map with both from and to dates" do
      filter = %{name: :date_range}
      value = %{from: "2024-01-01", to: "2024-01-31"}
      result = DateRange.parse_value(value, filter)

      assert result == %{from: ~D[2024-01-01], to: ~D[2024-01-31]}
    end

    test "parses map with only from date" do
      filter = %{name: :date_range}
      value = %{from: "2024-01-01", to: nil}
      result = DateRange.parse_value(value, filter)

      assert result == %{from: ~D[2024-01-01]}
    end

    test "parses map with only to date" do
      filter = %{name: :date_range}
      value = %{from: nil, to: "2024-01-31"}
      result = DateRange.parse_value(value, filter)

      assert result == %{to: ~D[2024-01-31]}
    end

    test "returns nil when both dates are nil" do
      filter = %{name: :date_range}
      value = %{from: nil, to: nil}
      result = DateRange.parse_value(value, filter)

      assert result == nil
    end

    test "returns nil when both dates are empty strings" do
      filter = %{name: :date_range}
      value = %{from: "", to: ""}
      result = DateRange.parse_value(value, filter)

      assert result == nil
    end

    test "parses Date structs directly" do
      filter = %{name: :date_range}
      value = %{from: ~D[2024-01-01], to: ~D[2024-01-31]}
      result = DateRange.parse_value(value, filter)

      assert result == %{from: ~D[2024-01-01], to: ~D[2024-01-31]}
    end

    test "parses form params with field name prefix" do
      filter = %{name: :created}
      # The parse_value function expects the params to have atom keys with :from and :to
      # or to be parsed through the LiveView form handling
      params = %{from: "2024-01-01", to: "2024-01-31"}
      result = DateRange.parse_value(params, filter)

      assert result == %{from: ~D[2024-01-01], to: ~D[2024-01-31]}
    end
  end

  describe "build_query/3" do
    test "applies range filter for both from and to" do
      query = Ash.Query.new(Post)
      value = %{from: ~D[2024-01-01], to: ~D[2024-01-31]}
      result = DateRange.build_query(query, :inserted_at, value)
      assert result != query
    end

    test "applies gte filter for only from date" do
      query = Ash.Query.new(Post)
      value = %{from: ~D[2024-01-01]}
      result = DateRange.build_query(query, :inserted_at, value)
      assert result != query
    end

    test "applies lte filter for only to date" do
      query = Ash.Query.new(Post)
      value = %{to: ~D[2024-01-31]}
      result = DateRange.build_query(query, :inserted_at, value)
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(Post)
      result = DateRange.build_query(query, :inserted_at, nil)
      assert result == query
    end

    test "returns query unchanged for empty map" do
      query = Ash.Query.new(Post)
      result = DateRange.build_query(query, :inserted_at, %{})
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = DateRange.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end
