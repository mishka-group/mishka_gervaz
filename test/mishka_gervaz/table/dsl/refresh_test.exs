defmodule MishkaGervaz.DSL.RefreshTest do
  @moduledoc """
  Tests for the refresh DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.Post
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  describe "refresh configuration" do
    test "refresh config is present" do
      config = ResourceInfo.refresh_config(Post)
      assert config != nil
    end

    test "refresh enabled key is configured" do
      config = ResourceInfo.refresh_config(Post)
      assert config.enabled == false
    end

    test "refresh interval key is configured" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.interval == 30_000
    end

    test "refresh pause_on_interaction key is configured" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.pause_on_interaction == true
    end

    test "refresh show_indicator key is configured" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.show_indicator == true
    end

    test "refresh pause_on_blur key is configured" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.pause_on_blur == true
    end
  end

  describe "refresh defaults" do
    test "enabled defaults to true in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Refresh.section().schema
      enabled_config = Keyword.get(schema, :enabled)
      assert Keyword.get(enabled_config, :default) == true
    end

    test "interval has no default in resource DSL (inherits from domain)" do
      schema = MishkaGervaz.Table.Dsl.Refresh.section().schema
      interval_config = Keyword.get(schema, :interval)
      # No default at resource level - inherits from domain
      assert Keyword.get(interval_config, :default) == nil
    end

    test "pause_on_interaction has no default in resource DSL (inherits from domain)" do
      schema = MishkaGervaz.Table.Dsl.Refresh.section().schema
      pause_config = Keyword.get(schema, :pause_on_interaction)
      assert Keyword.get(pause_config, :default) == nil
    end

    test "show_indicator has no default in resource DSL (inherits from domain)" do
      schema = MishkaGervaz.Table.Dsl.Refresh.section().schema
      show_config = Keyword.get(schema, :show_indicator)
      assert Keyword.get(show_config, :default) == nil
    end

    test "pause_on_blur has no default in resource DSL (inherits from domain)" do
      schema = MishkaGervaz.Table.Dsl.Refresh.section().schema
      pause_blur_config = Keyword.get(schema, :pause_on_blur)
      assert Keyword.get(pause_blur_config, :default) == nil
    end
  end

  describe "refresh via TableInfo" do
    test "TableInfo.refresh/1 returns all refresh keys" do
      refresh = TableInfo.refresh(ComplexTestResource)

      assert is_map(refresh)
      assert Map.has_key?(refresh, :enabled)
      assert Map.has_key?(refresh, :interval)
      assert Map.has_key?(refresh, :pause_on_interaction)
      assert Map.has_key?(refresh, :show_indicator)
      assert Map.has_key?(refresh, :pause_on_blur)
    end

    test "TableInfo.refresh/1 returns correct values from DSL" do
      refresh = TableInfo.refresh(ComplexTestResource)

      assert refresh.enabled == true
      assert refresh.interval == 30_000
      assert refresh.pause_on_interaction == true
      assert refresh.show_indicator == true
      assert refresh.pause_on_blur == true
    end
  end
end
