defmodule MishkaGervaz.Types.Filter.RelationTest do
  @moduledoc """
  Tests for the Relation filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Relation
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Relation.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Relation.parse_value("", %{}) == nil
    end

    test "returns :nil_value for __nil__ string" do
      assert Relation.parse_value("__nil__", %{}) == :nil_value
    end

    test "returns value as-is for UUID string" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert Relation.parse_value(uuid, %{}) == uuid
    end

    test "returns value as-is for any other string" do
      assert Relation.parse_value("some_id", %{}) == "some_id"
    end
  end

  describe "build_query/3" do
    test "applies is_nil filter for :nil_value" do
      query = Ash.Query.new(Post)
      result = Relation.build_query(query, :user_id, :nil_value)
      assert result != query
    end

    test "applies eq filter for normal value" do
      query = Ash.Query.new(Post)
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      result = Relation.build_query(query, :user_id, uuid)
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(Post)
      result = Relation.build_query(query, :user_id, nil)
      assert result == query
    end

    test "returns query unchanged for empty string" do
      query = Ash.Query.new(Post)
      result = Relation.build_query(query, :user_id, "")
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Relation.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end
