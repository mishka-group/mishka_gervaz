defmodule MishkaGervaz.DSL.UrlSyncTest do
  @moduledoc """
  Tests for the url_sync DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.Post

  describe "url_sync configuration" do
    test "url_sync config is present" do
      config = ResourceInfo.url_sync_config(Post)
      assert config != nil
    end

    test "url_sync enabled key is configured" do
      config = ResourceInfo.url_sync_config(Post)
      assert config.enabled == true
    end

    test "url_sync params key is configured" do
      config = ResourceInfo.url_sync_config(Post)
      assert is_list(config.params)
      assert :page in config.params
      assert :sort in config.params
      assert :search in config.params
      assert :filters in config.params
    end

    test "url_sync mode key is configured to bidirectional" do
      config = ResourceInfo.url_sync_config(Post)
      assert config.mode == :bidirectional
    end

    test "url_sync prefix key is nil when not specified" do
      config = ResourceInfo.url_sync_config(Post)
      assert Map.get(config, :prefix) == nil
    end

    test "url_sync max_filter_length key uses default 500 when not specified" do
      config = ResourceInfo.url_sync_config(Post)
      assert config.max_filter_length == 500
    end
  end

  describe "url_sync defaults" do
    test "mode defaults to :read_only in DSL schema" do
      # Verify the default value matches DSL schema
      schema = MishkaGervaz.Table.Dsl.UrlSync.section().schema
      mode_config = Keyword.get(schema, :mode)
      assert Keyword.get(mode_config, :default) == :read_only
    end

    test "enabled defaults to true in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.UrlSync.section().schema
      enabled_config = Keyword.get(schema, :enabled)
      assert Keyword.get(enabled_config, :default) == true
    end

    test "max_filter_length defaults to 500 in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.UrlSync.section().schema
      max_filter_config = Keyword.get(schema, :max_filter_length)
      assert Keyword.get(max_filter_config, :default) == 500
    end
  end

  describe "url_sync via TableInfo" do
    test "TableInfo.url_sync/1 returns all url_sync keys" do
      url_sync = TableInfo.url_sync(Post)

      assert is_map(url_sync)
      assert Map.has_key?(url_sync, :enabled)
      assert Map.has_key?(url_sync, :mode)
      assert Map.has_key?(url_sync, :params)
      assert Map.has_key?(url_sync, :max_filter_length)
      assert Map.get(url_sync, :prefix) == nil
    end

    test "TableInfo.url_sync/1 returns correct values from DSL" do
      url_sync = TableInfo.url_sync(Post)

      assert url_sync.enabled == true
      assert url_sync.mode == :bidirectional
      assert :page in url_sync.params
    end
  end

  describe "preserve_params DSL" do
    test "preserve_params has no default in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.UrlSync.section().schema
      preserve_config = Keyword.get(schema, :preserve_params)

      refute Keyword.has_key?(preserve_config, :default)
    end

    test "preserve_params is available via TableInfo when configured" do
      url_sync = TableInfo.url_sync(Post)

      assert url_sync[:preserve_params] == [:return_to]
    end

    test "preserve_params :all is available via TableInfo" do
      alias MishkaGervaz.Test.Resources.ComplexTestResource
      url_sync = TableInfo.url_sync(ComplexTestResource)

      assert url_sync[:preserve_params] == :all
    end

    test "preserve_params is nil via TableInfo when not configured" do
      # Resources without preserve_params should not have it in the map
      # (map_put_if_set skips nil values)
      alias MishkaGervaz.Test.Resources.Comment
      url_sync = TableInfo.url_sync(Comment)

      if url_sync do
        refute Map.has_key?(url_sync, :preserve_params)
      end
    end
  end
end
