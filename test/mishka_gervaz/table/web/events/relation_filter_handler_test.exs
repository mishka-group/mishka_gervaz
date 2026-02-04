defmodule MishkaGervaz.Table.Web.Events.RelationFilterHandlerTest do
  @moduledoc """
  Tests for the RelationFilterHandler module.

  Tests the public validation functions:
  - `skip_relation_search_term?/2` - Check if a value should be skipped as a filter value
  - `valid_relation_value?/2` - Check if a value is valid for the given ID type
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Events.RelationFilterHandler

  describe "skip_relation_search_term?/2" do
    test "returns true for search term in relation filter with search mode and UUID id_type" do
      filter = %{type: :relation, mode: :search, id_type: :uuid}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "some search text") == true
    end

    test "returns true for search term in relation filter with search_multi mode and UUID id_type" do
      filter = %{type: :relation, mode: :search_multi, id_type: :uuid}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "another search") == true
    end

    test "returns false for valid UUID in relation filter with search mode" do
      filter = %{type: :relation, mode: :search, id_type: :uuid}
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert RelationFilterHandler.skip_relation_search_term?(filter, uuid) == false
    end

    test "returns false for __nil__ value in relation filter" do
      filter = %{type: :relation, mode: :search, id_type: :uuid}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "__nil__") == false
    end

    test "returns false for non-relation filter types" do
      filter = %{type: :text}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "any value") == false
    end

    test "returns false for static mode relation filters" do
      filter = %{type: :relation, mode: :static, id_type: :uuid}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "search text") == false
    end

    test "returns false for load_more mode relation filters" do
      filter = %{type: :relation, mode: :load_more, id_type: :uuid}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "search text") == false
    end

    test "returns false for non-string values" do
      filter = %{type: :relation, mode: :search, id_type: :uuid}
      assert RelationFilterHandler.skip_relation_search_term?(filter, 123) == false
      assert RelationFilterHandler.skip_relation_search_term?(filter, nil) == false
    end

    # Integer ID type tests
    test "returns true for non-integer search term with integer id_type" do
      filter = %{type: :relation, mode: :search, id_type: :integer}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "search text") == true
    end

    test "returns false for valid integer string with integer id_type" do
      filter = %{type: :relation, mode: :search, id_type: :integer}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "123") == false
    end

    test "returns false for negative integer string with integer id_type" do
      filter = %{type: :relation, mode: :search, id_type: :integer}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "-456") == false
    end

    test "returns true for integer with trailing text" do
      filter = %{type: :relation, mode: :search, id_type: :integer}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "123abc") == true
    end

    # String ID type tests
    test "returns false for any non-empty string with string id_type" do
      filter = %{type: :relation, mode: :search, id_type: :string}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "any-string-value") == false
    end

    test "returns false for search term with string id_type" do
      filter = %{type: :relation, mode: :search, id_type: :string}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "search text") == false
    end

    # UUID v7 tests
    test "returns true for search term with uuid_v7 id_type" do
      filter = %{type: :relation, mode: :search, id_type: :uuid_v7}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "search text") == true
    end

    test "returns false for valid UUID with uuid_v7 id_type" do
      filter = %{type: :relation, mode: :search, id_type: :uuid_v7}
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert RelationFilterHandler.skip_relation_search_term?(filter, uuid) == false
    end

    # Backwards compatibility test (no id_type)
    test "falls back to UUID validation when id_type is not set" do
      filter = %{type: :relation, mode: :search}
      assert RelationFilterHandler.skip_relation_search_term?(filter, "search text") == true

      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert RelationFilterHandler.skip_relation_search_term?(filter, uuid) == false
    end
  end

  describe "valid_relation_value?/2" do
    # __nil__ value tests
    test "returns true for __nil__ regardless of id_type" do
      assert RelationFilterHandler.valid_relation_value?("__nil__", :uuid) == true
      assert RelationFilterHandler.valid_relation_value?("__nil__", :integer) == true
      assert RelationFilterHandler.valid_relation_value?("__nil__", :string) == true
      assert RelationFilterHandler.valid_relation_value?("__nil__", :uuid_v7) == true
    end

    # UUID validation
    test "returns true for valid UUID with :uuid id_type" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert RelationFilterHandler.valid_relation_value?(uuid, :uuid) == true
    end

    test "returns false for invalid UUID with :uuid id_type" do
      assert RelationFilterHandler.valid_relation_value?("not-a-uuid", :uuid) == false
      assert RelationFilterHandler.valid_relation_value?("search text", :uuid) == false
    end

    test "returns true for valid lowercase UUID" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert RelationFilterHandler.valid_relation_value?(uuid, :uuid) == true
    end

    test "returns true for valid uppercase UUID" do
      uuid = "550E8400-E29B-41D4-A716-446655440000"
      assert RelationFilterHandler.valid_relation_value?(uuid, :uuid) == true
    end

    # UUID v7 validation (same format as UUID)
    test "returns true for valid UUID with :uuid_v7 id_type" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert RelationFilterHandler.valid_relation_value?(uuid, :uuid_v7) == true
    end

    test "returns false for invalid UUID with :uuid_v7 id_type" do
      assert RelationFilterHandler.valid_relation_value?("not-a-uuid", :uuid_v7) == false
    end

    # Integer validation
    test "returns true for valid integer string with :integer id_type" do
      assert RelationFilterHandler.valid_relation_value?("123", :integer) == true
      assert RelationFilterHandler.valid_relation_value?("0", :integer) == true
      assert RelationFilterHandler.valid_relation_value?("-456", :integer) == true
    end

    test "returns false for invalid integer string with :integer id_type" do
      assert RelationFilterHandler.valid_relation_value?("abc", :integer) == false
      assert RelationFilterHandler.valid_relation_value?("12.34", :integer) == false
      assert RelationFilterHandler.valid_relation_value?("123abc", :integer) == false
    end

    test "returns false for empty string with :integer id_type" do
      assert RelationFilterHandler.valid_relation_value?("", :integer) == false
    end

    # String validation
    test "returns true for any non-empty string with :string id_type" do
      assert RelationFilterHandler.valid_relation_value?("any-value", :string) == true
      assert RelationFilterHandler.valid_relation_value?("123", :string) == true
      assert RelationFilterHandler.valid_relation_value?("with spaces", :string) == true
    end

    test "returns false for empty string with :string id_type" do
      assert RelationFilterHandler.valid_relation_value?("", :string) == false
    end

    # Non-binary values
    test "returns false for non-binary values" do
      assert RelationFilterHandler.valid_relation_value?(123, :integer) == false
      assert RelationFilterHandler.valid_relation_value?(nil, :uuid) == false
      assert RelationFilterHandler.valid_relation_value?(:atom, :string) == false
    end
  end
end
