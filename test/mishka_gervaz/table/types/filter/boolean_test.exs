defmodule MishkaGervaz.Types.Filter.BooleanTest do
  @moduledoc """
  Tests for the Boolean filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Boolean
  alias MishkaGervaz.Test.Resources.User

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Boolean.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Boolean.parse_value("", %{}) == nil
    end

    test "returns true for 'true' string" do
      assert Boolean.parse_value("true", %{}) == true
    end

    test "returns false for 'false' string" do
      assert Boolean.parse_value("false", %{}) == false
    end

    test "returns true for true boolean" do
      assert Boolean.parse_value(true, %{}) == true
    end

    test "returns false for false boolean" do
      assert Boolean.parse_value(false, %{}) == false
    end

    test "returns nil for other values" do
      assert Boolean.parse_value("invalid", %{}) == nil
      assert Boolean.parse_value(123, %{}) == nil
    end
  end

  describe "build_query/3" do
    test "applies eq true filter for true value" do
      query = Ash.Query.new(User)
      result = Boolean.build_query(query, :active, true)
      assert result != query
    end

    test "applies eq false filter for false value" do
      query = Ash.Query.new(User)
      result = Boolean.build_query(query, :active, false)
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(User)
      result = Boolean.build_query(query, :active, nil)
      assert result == query
    end

    test "returns query unchanged for other values" do
      query = Ash.Query.new(User)
      result = Boolean.build_query(query, :active, "maybe")
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Boolean.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end
