defmodule MishkaGervaz.DSL.FiltersTest do
  @moduledoc """
  Tests for the filters DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Table.Web.State

  alias MishkaGervaz.Test.Resources.{
    Post,
    User,
    Comment,
    ComplexTestResource,
    DynamicOptionsResource
  }

  # Helper to get the UI config from a filter (handles list or single struct)
  defp get_ui(filter) do
    case filter.ui do
      [ui | _] -> ui
      ui when is_struct(ui) -> ui
      _ -> nil
    end
  end

  # Helper to get the preload config from a filter (handles list or single struct)
  defp get_preload(filter) do
    case filter.preload do
      [preload | _] -> preload
      preload when is_struct(preload) -> preload
      _ -> nil
    end
  end

  describe "filter definitions" do
    test "returns all filters for a resource" do
      filters = ResourceInfo.filters(Post)
      assert is_list(filters)
      assert length(filters) > 0
    end

    test "each filter is a Filter struct" do
      filters = ResourceInfo.filters(Post)

      Enum.each(filters, fn filter ->
        assert is_struct(filter, MishkaGervaz.Table.Entities.Filter)
      end)
    end

    test "retrieves specific filter by name" do
      filter = ResourceInfo.filter(Post, :search)
      assert filter.name == :search
    end

    test "returns nil for non-existent filter" do
      filter = ResourceInfo.filter(Post, :non_existent)
      assert filter == nil
    end
  end

  describe "text filter type" do
    test "text filter has correct type" do
      filter = ResourceInfo.filter(Post, :search)
      assert filter.type == :text
    end

    test "text filter has fields configuration" do
      filter = ResourceInfo.filter(Post, :search)
      assert filter.fields == [:title, :content]
    end

    test "text filter ui configuration" do
      filter = ResourceInfo.filter(Post, :search)
      ui = get_ui(filter)
      assert ui.placeholder == "Search posts..."
    end

    test "User text filter configuration" do
      filter = ResourceInfo.filter(User, :search)
      ui = get_ui(filter)
      assert filter.type == :text
      assert filter.fields == [:name, :email]
      assert ui.label == "Search"
      assert ui.placeholder == "Search users..."
    end
  end

  describe "select filter type" do
    test "select filter has correct type" do
      filter = ResourceInfo.filter(Post, :status)
      assert filter.type == :select
    end

    test "select filter has options" do
      filter = ResourceInfo.filter(Post, :status)
      assert is_list(filter.options)
      assert length(filter.options) == 3

      option_values = Enum.map(filter.options, & &1[:value])
      assert "draft" in option_values
      assert "published" in option_values
      assert "archived" in option_values
    end

    test "select filter options have labels" do
      filter = ResourceInfo.filter(Post, :status)
      draft_option = Enum.find(filter.options, &(&1[:value] == "draft"))
      assert draft_option[:label] == "Draft"
    end

    test "select filter has default value" do
      filter = ResourceInfo.filter(Post, :status)
      assert filter.default == "published"
    end

    test "User role select filter" do
      filter = ResourceInfo.filter(User, :role)
      assert filter.type == :select
      option_values = Enum.map(filter.options, & &1[:value])
      assert "admin" in option_values
      assert "user" in option_values
      assert "guest" in option_values
    end
  end

  describe "select filter with auto-detected options from attribute constraint" do
    test "select filter without explicit options resolves from one_of in compiled config" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))

      assert priority_filter.type == :select
      assert is_list(priority_filter.options)
      assert length(priority_filter.options) == 4
    end

    test "auto-detected options are humanized tuples in compiled config" do
      config = ResourceInfo.table_config(DynamicOptionsResource)
      priority_filter = Enum.find(config.filters.list, &(&1.name == :priority))

      assert {"Low", :low} in priority_filter.options
      assert {"Medium", :medium} in priority_filter.options
      assert {"High", :high} in priority_filter.options
      assert {"Critical", :critical} in priority_filter.options
    end

    test "raw DSL entity has nil options before transformer resolves them" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :priority)
      assert filter.type == :select
      assert filter.options == nil
    end

    test "Post status select with explicit options ignores attribute constraint" do
      filter = ResourceInfo.filter(Post, :status)

      # Post uses explicit keyword-list options, not auto-detected tuples
      option_values = Enum.map(filter.options, & &1[:value])
      assert "draft" in option_values
      assert "published" in option_values
      assert "archived" in option_values
    end

    test "explicit options take priority over auto-detection in compiled config" do
      # Post has both: explicit options AND status attr with one_of constraint
      # The explicit options should win
      config = ResourceInfo.table_config(Post)
      status_filter = Enum.find(config.filters.list, &(&1.name == :status))
      assert length(status_filter.options) == 3

      # These are keyword-list style from explicit options, not humanized tuples
      first = hd(status_filter.options)
      assert is_list(first)
      assert Keyword.has_key?(first, :value)
      assert Keyword.has_key?(first, :label)
    end
  end

  describe "select filter with runtime callback function" do
    test "function options are stored as function in DSL config" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :language)
      assert filter.type == :select
      assert is_function(filter.options, 0)
    end

    test "calling function options returns expected list" do
      filter = ResourceInfo.filter(DynamicOptionsResource, :language)
      result = filter.options.()

      assert {"English", "en"} in result
      assert {"Persian", "fa"} in result
      assert {"Arabic", "ar"} in result
    end
  end

  describe "boolean filter type" do
    test "boolean filter has correct type" do
      filter = ResourceInfo.filter(User, :active)
      assert filter.type == :boolean
    end

    test "boolean filter ui configuration" do
      filter = ResourceInfo.filter(User, :active)
      ui = get_ui(filter)
      assert ui.label == "Active Only"
    end

    test "Comment approved boolean filter" do
      filter = ResourceInfo.filter(Comment, :approved)
      ui = get_ui(filter)
      assert filter.type == :boolean
      assert ui.label == "Approved Only"
    end
  end

  describe "relation filter type" do
    test "relation filter has correct type" do
      filter = ResourceInfo.filter(Post, :user_id)
      assert filter.type == :relation
    end

    test "relation filter has resource reference" do
      filter = ResourceInfo.filter(Post, :user_id)
      assert filter.resource == MishkaGervaz.Test.Resources.User
    end

    test "relation filter has display_field" do
      filter = ResourceInfo.filter(Post, :user_id)
      assert filter.display_field == :name
    end

    test "relation filter ui configuration" do
      filter = ResourceInfo.filter(Post, :user_id)
      ui = get_ui(filter)
      assert ui.label == "Author"
    end
  end

  describe "filter dependencies (depends_on)" do
    test "Comment user_id filter depends on post_id" do
      filter = ResourceInfo.filter(Comment, :user_id)
      assert filter.depends_on == :post_id
    end

    test "dependent filter has disabled prompt" do
      filter = ResourceInfo.filter(Comment, :user_id)
      ui = get_ui(filter)
      assert ui.disabled_prompt == "Select a post first"
    end

    test "Comment post_id filter has no dependency" do
      filter = ResourceInfo.filter(Comment, :post_id)
      assert filter.depends_on == nil
    end
  end

  describe "filter count by resource" do
    test "Post has correct number of filters" do
      filters = ResourceInfo.filters(Post)
      assert length(filters) == 3
    end

    test "User has correct number of filters" do
      filters = ResourceInfo.filters(User)
      assert length(filters) == 3
    end

    test "Comment has correct number of filters" do
      filters = ResourceInfo.filters(Comment)
      assert length(filters) == 3
    end
  end

  describe "filter default values in State" do
    test "State.init builds filter_values from filter defaults" do
      state = State.init("test-table", Post, nil)
      assert state.filter_values == %{status: "published"}
    end

    test "filter without default is not included in filter_values" do
      state = State.init("test-table", User, nil)
      # User filters have no defaults
      assert state.filter_values == %{}
    end
  end

  describe "all Filter entity keys (ComplexTestResource)" do
    test "name key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      assert filter.name == :search
    end

    test "type key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      assert filter.type == :text
    end

    test "source key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :status)
      assert filter.source == :status
    end

    test "fields key is configured for text filter" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      assert filter.fields == [:title, :content]
    end

    test "visible key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      assert filter.visible == true
    end

    test "min_chars key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      assert filter.min_chars == 3
    end

    test "options key is configured for select filter" do
      filter = ResourceInfo.filter(ComplexTestResource, :status)
      assert is_list(filter.options)
      assert length(filter.options) == 3
    end

    test "include_nil key is configured with string value" do
      filter = ResourceInfo.filter(ComplexTestResource, :status)
      assert filter.include_nil == "All Statuses"
    end

    test "min key is configured for number filter" do
      filter = ResourceInfo.filter(ComplexTestResource, :view_count)
      assert filter.min == 0
    end

    test "max key is configured for number filter" do
      filter = ResourceInfo.filter(ComplexTestResource, :view_count)
      assert filter.max == 1_000_000
    end

    test "display_field key is configured for relation filter" do
      filter = ResourceInfo.filter(ComplexTestResource, :author_id)
      assert filter.display_field == :name
    end

    test "search_field key is configured for relation filter" do
      filter = ResourceInfo.filter(ComplexTestResource, :author_id)
      assert filter.search_field == :name
    end
  end

  describe "all Filter.Ui keys (ComplexTestResource)" do
    test "ui label key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      ui = get_ui(filter)
      assert ui.label == "Search"
    end

    test "ui placeholder key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      ui = get_ui(filter)
      assert ui.placeholder == "Search posts..."
    end

    test "ui icon key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      ui = get_ui(filter)
      assert ui.icon == "hero-magnifying-glass"
    end

    test "ui debounce key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      ui = get_ui(filter)
      assert ui.debounce == 400
    end

    test "ui extra key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      ui = get_ui(filter)
      assert ui.extra == %{autofocus: true}
    end

    test "ui prompt key is configured" do
      filter = ResourceInfo.filter(ComplexTestResource, :status)
      ui = get_ui(filter)
      assert ui.prompt == "All"
    end
  end

  describe "Filter entity defaults" do
    test "type defaults to :text in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      type_config = Keyword.get(schema, :type)
      assert Keyword.get(type_config, :default) == :text
    end

    test "visible defaults to true in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      visible_config = Keyword.get(schema, :visible)
      assert Keyword.get(visible_config, :default) == true
    end

    test "restricted defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      restricted_config = Keyword.get(schema, :restricted)
      assert Keyword.get(restricted_config, :default) == false
    end

    test "include_nil defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      include_nil_config = Keyword.get(schema, :include_nil)
      assert Keyword.get(include_nil_config, :default) == false
    end

    test "min_chars defaults to 2 in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      min_chars_config = Keyword.get(schema, :min_chars)
      assert Keyword.get(min_chars_config, :default) == 2
    end

    test "virtual defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      virtual_config = Keyword.get(schema, :virtual)
      assert Keyword.get(virtual_config, :default) == false
    end

    test "load_action defaults to :read in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.opt_schema()
      load_action_config = Keyword.get(schema, :load_action)
      assert Keyword.get(load_action_config, :default) == :read
    end
  end

  describe "Filter.Ui entity defaults" do
    test "prompt defaults to 'Select...' in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.Ui.opt_schema()
      prompt_config = Keyword.get(schema, :prompt)
      assert Keyword.get(prompt_config, :default) == "Select..."
    end

    test "disabled_prompt defaults to nil in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.Ui.opt_schema()
      disabled_config = Keyword.get(schema, :disabled_prompt)
      assert Keyword.get(disabled_config, :default) == nil
    end

    test "debounce defaults to 300 in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.Ui.opt_schema()
      debounce_config = Keyword.get(schema, :debounce)
      assert Keyword.get(debounce_config, :default) == 300
    end

    test "extra defaults to empty map in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Filter.Ui.opt_schema()
      extra_config = Keyword.get(schema, :extra)
      assert Keyword.get(extra_config, :default) == %{}
    end
  end

  describe "filter preload DSL" do
    test "relation filter can have preload configuration" do
      filter = ResourceInfo.filter(Post, :user_id)
      preload = get_preload(filter)
      assert preload != nil
      assert is_struct(preload, MishkaGervaz.Table.Entities.Filter.Preload)
    end

    test "preload always is accessible from filter" do
      filter = ResourceInfo.filter(Post, :user_id)
      preload = get_preload(filter)
      assert preload.always == [:posts]
    end

    test "preload master defaults to nil when not set" do
      filter = ResourceInfo.filter(Post, :user_id)
      preload = get_preload(filter)
      assert preload.master == nil
    end

    test "preload tenant defaults to nil when not set" do
      filter = ResourceInfo.filter(Post, :user_id)
      preload = get_preload(filter)
      assert preload.tenant == nil
    end

    test "filter without preload returns nil from get_preload" do
      filter = ResourceInfo.filter(Post, :status)
      preload = get_preload(filter)
      assert preload == nil
    end

    test "Filter.Preload entity has correct struct fields" do
      filter = ResourceInfo.filter(Post, :user_id)
      preload = get_preload(filter)
      assert Map.has_key?(preload, :always)
      assert Map.has_key?(preload, :master)
      assert Map.has_key?(preload, :tenant)
    end
  end

  describe "filters via TableInfo" do
    test "TableInfo.filters/1 returns all filters" do
      filters = TableInfo.filters(ComplexTestResource)
      assert is_list(filters)
      filter_names = Enum.map(filters, & &1.name)
      assert :search in filter_names
      assert :status in filter_names
    end

    test "TableInfo.filter/2 returns specific filter" do
      filter = TableInfo.filter(ComplexTestResource, :search)
      assert filter.name == :search
    end

    test "TableInfo.filter_mode/1 returns filter mode" do
      mode = TableInfo.filter_mode(ComplexTestResource)
      assert mode == :inline
    end
  end
end
