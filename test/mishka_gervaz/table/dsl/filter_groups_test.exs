defmodule MishkaGervaz.DSL.FilterGroupsTest do
  @moduledoc """
  Tests for the filter_groups DSL section (sibling to filters).
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo

  alias MishkaGervaz.Test.Resources.ComplexTestResource

  describe "filter groups via TableInfo" do
    test "filter_groups/1 returns all groups" do
      groups = TableInfo.filter_groups(ComplexTestResource)
      assert is_list(groups)
      assert length(groups) == 2
    end

    test "filter_group/2 returns specific group by name" do
      group = TableInfo.filter_group(ComplexTestResource, :primary)
      assert group != nil
      assert group.name == :primary
    end

    test "filter_group/2 returns nil for non-existent group" do
      group = TableInfo.filter_group(ComplexTestResource, :non_existent)
      assert group == nil
    end

    test "filter_groups/1 returns empty list for resource without groups" do
      groups = TableInfo.filter_groups(MishkaGervaz.Test.Resources.Post)
      assert groups == []
    end
  end

  describe "filter groups via ResourceInfo delegations" do
    test "table_filter_groups/1 returns all groups" do
      groups = ResourceInfo.table_filter_groups(ComplexTestResource)
      assert is_list(groups)
      assert length(groups) == 2
    end

    test "table_filter_group/2 returns specific group" do
      group = ResourceInfo.table_filter_group(ComplexTestResource, :advanced)
      assert group != nil
      assert group.name == :advanced
    end
  end

  describe "primary group configuration" do
    test "has correct filters" do
      group = TableInfo.filter_group(ComplexTestResource, :primary)
      assert group.filters == [:search]
    end

    test "is not collapsible" do
      group = TableInfo.filter_group(ComplexTestResource, :primary)
      assert group.collapsible == false
    end

    test "is not collapsed" do
      group = TableInfo.filter_group(ComplexTestResource, :primary)
      assert group.collapsed == false
    end

    test "has position :first" do
      group = TableInfo.filter_group(ComplexTestResource, :primary)
      assert group.position == :first
    end

    test "has ui label" do
      group = TableInfo.filter_group(ComplexTestResource, :primary)
      assert group.ui != nil
      assert group.ui.label == "Search"
    end
  end

  describe "advanced group configuration" do
    test "has correct filters" do
      group = TableInfo.filter_group(ComplexTestResource, :advanced)
      assert group.filters == [:status, :is_featured, :author_id]
    end

    test "is collapsible" do
      group = TableInfo.filter_group(ComplexTestResource, :advanced)
      assert group.collapsible == true
    end

    test "starts collapsed" do
      group = TableInfo.filter_group(ComplexTestResource, :advanced)
      assert group.collapsed == true
    end

    test "has ui label" do
      group = TableInfo.filter_group(ComplexTestResource, :advanced)
      assert group.ui.label == "Advanced Filters"
    end

    test "has ui icon" do
      group = TableInfo.filter_group(ComplexTestResource, :advanced)
      assert group.ui.icon == "hero-funnel"
    end

    test "has ui columns override" do
      group = TableInfo.filter_group(ComplexTestResource, :advanced)
      assert group.ui.columns == 3
    end
  end

  describe "filter groups in compiled config" do
    test "groups are top-level in config" do
      config = TableInfo.config(ComplexTestResource)
      assert is_list(config.filter_groups)
      assert length(config.filter_groups) == 2
    end

    test "group maps have correct keys" do
      config = TableInfo.config(ComplexTestResource)
      group = Enum.find(config.filter_groups, &(&1.name == :advanced))

      assert Map.has_key?(group, :name)
      assert Map.has_key?(group, :filters)
      assert Map.has_key?(group, :collapsed)
      assert Map.has_key?(group, :collapsible)
      assert Map.has_key?(group, :visible)
      assert Map.has_key?(group, :restricted)
      assert Map.has_key?(group, :position)
      assert Map.has_key?(group, :ui)
    end
  end

  describe "filter_mode via presentation" do
    test "filter_mode defaults to :inline" do
      mode = TableInfo.filter_mode(ComplexTestResource)
      assert mode == :inline
    end

    test "filter_mode available via ResourceInfo" do
      mode = ResourceInfo.table_filter_mode(ComplexTestResource)
      assert mode == :inline
    end
  end

  describe "filter group entity defaults" do
    test "collapsed defaults to false" do
      schema = MishkaGervaz.Table.Entities.FilterGroup.opt_schema()
      assert Keyword.get(Keyword.get(schema, :collapsed), :default) == false
    end

    test "collapsible defaults to false" do
      schema = MishkaGervaz.Table.Entities.FilterGroup.opt_schema()
      assert Keyword.get(Keyword.get(schema, :collapsible), :default) == false
    end

    test "visible defaults to true" do
      schema = MishkaGervaz.Table.Entities.FilterGroup.opt_schema()
      assert Keyword.get(Keyword.get(schema, :visible), :default) == true
    end

    test "restricted defaults to false" do
      schema = MishkaGervaz.Table.Entities.FilterGroup.opt_schema()
      assert Keyword.get(Keyword.get(schema, :restricted), :default) == false
    end
  end

  describe "filter group UI entity defaults" do
    test "extra defaults to empty map" do
      schema = MishkaGervaz.Table.Entities.FilterGroup.Ui.opt_schema()
      assert Keyword.get(Keyword.get(schema, :extra), :default) == %{}
    end
  end

  describe "existing filter tests still pass with groups" do
    test "filters still accessible individually" do
      filter = TableInfo.filter(ComplexTestResource, :search)
      assert filter.name == :search
      assert filter.type == :text
    end
  end
end
