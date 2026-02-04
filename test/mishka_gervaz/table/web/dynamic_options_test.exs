defmodule MishkaGervaz.Table.Web.DynamicOptionsTest do
  @moduledoc """
  Tests for dynamic (function-based) filter options support.

  Verifies that:
  - DSL accepts zero-arity functions for filter options
  - FilterBuilder resolves function options at build time
  - Static list options continue to work unchanged
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Table.Web.State.FilterBuilder.Default, as: FilterBuilder
  alias MishkaGervaz.Test.Resources.DynamicOptionsResource

  describe "DSL acceptance of function options" do
    test "filter with function options stores a function in DSL config" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :language)
      assert is_function(filter.options, 0)
    end

    test "filter with static list options stores a list in DSL config" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :category)
      assert is_list(filter.options)
      assert length(filter.options) == 2
    end

    test "calling the function options returns the expected list" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :language)
      result = filter.options.()
      assert result == [{"English", "en"}, {"Persian", "fa"}, {"Arabic", "ar"}]
    end
  end

  describe "FilterBuilder resolves function options" do
    test "function options are resolved to a list after build" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      language_filter = Enum.find(filters, &(&1.name == :language))
      assert is_list(language_filter.options)
      assert length(language_filter.options) == 3
    end

    test "resolved function options contain correct values" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      language_filter = Enum.find(filters, &(&1.name == :language))
      assert {"English", "en"} in language_filter.options
      assert {"Persian", "fa"} in language_filter.options
      assert {"Arabic", "ar"} in language_filter.options
    end

    test "static list options remain unchanged after build" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      category_filter = Enum.find(filters, &(&1.name == :category))
      assert is_list(category_filter.options)
      assert length(category_filter.options) == 2
    end

    test "text filter without options is unaffected" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      search_filter = Enum.find(filters, &(&1.name == :search))
      assert search_filter.options == nil
    end
  end

  describe "auto-detect options from attribute one_of constraint" do
    test "raw DSL entity has nil options for auto-detected filter" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :priority)
      assert filter.options == nil
    end

    test "compiled config resolves options from attribute one_of constraint" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))
      assert is_list(priority_filter.options)
      assert length(priority_filter.options) == 4
    end

    test "auto-detected options are {humanized_label, atom_value} tuples" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))

      assert {"Low", :low} in priority_filter.options
      assert {"Medium", :medium} in priority_filter.options
      assert {"High", :high} in priority_filter.options
      assert {"Critical", :critical} in priority_filter.options
    end

    test "auto-detected options preserve original atom values" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))
      values = Enum.map(priority_filter.options, &elem(&1, 1))

      assert :low in values
      assert :medium in values
      assert :high in values
      assert :critical in values
    end

    test "auto-detected options have humanized labels" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))
      labels = Enum.map(priority_filter.options, &elem(&1, 0))

      assert "Low" in labels
      assert "Medium" in labels
      assert "High" in labels
      assert "Critical" in labels
    end

    test "auto-detected options are resolved as list in FilterBuilder" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      priority_filter = Enum.find(filters, &(&1.name == :priority))
      assert is_list(priority_filter.options)
      assert length(priority_filter.options) == 4
    end

    test "auto-detected options remain stable after FilterBuilder build" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      priority_filter = Enum.find(filters, &(&1.name == :priority))
      assert {"Low", :low} in priority_filter.options
      assert {"Critical", :critical} in priority_filter.options
    end
  end

  describe "all three option strategies coexist in same resource" do
    test "static, function, and auto-detect filters all have correct options" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      filters = FilterBuilder.build(config, DynamicOptionsResource, nil)

      category = Enum.find(filters, &(&1.name == :category))
      language = Enum.find(filters, &(&1.name == :language))
      priority = Enum.find(filters, &(&1.name == :priority))

      # Static explicit list
      assert is_list(category.options)
      assert length(category.options) == 2

      # Runtime function callback
      assert is_list(language.options)
      assert length(language.options) == 3

      # Auto-detected from attribute one_of constraint
      assert is_list(priority.options)
      assert length(priority.options) == 4
    end

    test "all three are select type" do
      category = ResourceInfo.filter(DynamicOptionsResource, :category)
      language = ResourceInfo.filter(DynamicOptionsResource, :language)
      priority = ResourceInfo.filter(DynamicOptionsResource, :priority)

      assert category.type == :select
      assert language.type == :select
      assert priority.type == :select
    end
  end

  describe "function options edge cases" do
    test "function returning empty list results in empty options" do
      filter = %MishkaGervaz.Table.Entities.Filter{
        name: :empty_test,
        type: :select,
        options: fn -> [] end
      }

      # Simulate what FilterBuilder does
      resolved =
        if is_function(filter.options, 0) do
          Map.put(filter, :options, filter.options.())
        else
          filter
        end

      assert resolved.options == []
    end

    test "function returning keyword-style options resolves correctly" do
      filter = %MishkaGervaz.Table.Entities.Filter{
        name: :kw_test,
        type: :select,
        options: fn ->
          [[value: "a", label: "Option A"], [value: "b", label: "Option B"]]
        end
      }

      resolved =
        if is_function(filter.options, 0) do
          Map.put(filter, :options, filter.options.())
        else
          filter
        end

      assert length(resolved.options) == 2
    end

    test "nil options remain nil (no function resolution attempted)" do
      filter = %MishkaGervaz.Table.Entities.Filter{
        name: :nil_test,
        type: :select,
        options: nil
      }

      assert filter.options == nil
      refute is_function(filter.options, 0)
    end
  end
end
