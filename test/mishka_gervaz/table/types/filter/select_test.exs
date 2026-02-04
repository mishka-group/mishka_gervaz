defmodule MishkaGervaz.Types.Filter.SelectTest do
  @moduledoc """
  Tests for the Select filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Select
  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, DynamicOptionsResource}

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Select.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Select.parse_value("", %{}) == nil
    end

    test "returns :nil_value for __nil__ string" do
      assert Select.parse_value("__nil__", %{}) == :nil_value
    end

    test "returns value as-is for other strings" do
      assert Select.parse_value("published", %{}) == "published"
    end
  end

  describe "build_query/3" do
    test "applies is_nil filter for :nil_value" do
      query = Ash.Query.new(Post)
      result = Select.build_query(query, :status, :nil_value)
      assert result != query
    end

    test "applies eq filter for normal value" do
      query = Ash.Query.new(Post)
      result = Select.build_query(query, :status, "published")
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(Post)
      result = Select.build_query(query, :status, nil)
      assert result == query
    end

    test "returns query unchanged for empty string" do
      query = Ash.Query.new(Post)
      result = Select.build_query(query, :status, "")
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Select.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end

  describe "build_query with explicit static options" do
    test "filters using value from explicit options list" do
      query = Ash.Query.new(Post)
      result = Select.build_query(query, :status, "draft")
      assert result != query
    end

    test "explicit options are stored as keyword lists" do
      filter = ResourceInfo.filter(Post, :status)
      assert is_list(filter.options)

      first = hd(filter.options)
      assert is_list(first)
      assert Keyword.has_key?(first, :value)
    end
  end

  describe "build_query with function callback options" do
    test "filters using value from function-resolved options" do
      # DynamicOptionsResource :language uses fn -> [...] end
      query = Ash.Query.new(DynamicOptionsResource)
      result = Select.build_query(query, :language, "en")
      assert result != query
    end

    test "function options are zero-arity functions in DSL config" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :language)
      assert is_function(filter.options, 0)
    end
  end

  describe "build_query with auto-detected options from attribute constraint" do
    test "filters using atom value from auto-detected options" do
      query = Ash.Query.new(DynamicOptionsResource)
      result = Select.build_query(query, :priority, :high)
      assert result != query
    end

    test "auto-detected options are {string, atom} tuples in compiled config" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))
      assert is_list(priority_filter.options)

      Enum.each(priority_filter.options, fn {label, value} ->
        assert is_binary(label)
        assert is_atom(value)
      end)
    end

    test "auto-detected options match attribute one_of constraint values" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))
      values = Enum.map(priority_filter.options, &elem(&1, 1))

      assert Enum.sort(values) == Enum.sort([:low, :medium, :high, :critical])
    end

    test "raw DSL entity has nil options when auto-detected" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :priority)
      assert filter.options == nil
    end
  end
end
