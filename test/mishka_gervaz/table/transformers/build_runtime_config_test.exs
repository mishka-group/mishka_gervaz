defmodule MishkaGervaz.Transformers.BuildRuntimeConfigTest do
  @moduledoc """
  Tests for the BuildRuntimeConfig transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, Comment, MinimalResource, ComplexTestResource}

  describe "config structure" do
    test "config contains all required sections" do
      config = ResourceInfo.table_config(Post)

      assert Map.has_key?(config, :identity)
      assert Map.has_key?(config, :source)
      assert Map.has_key?(config, :columns)
      assert Map.has_key?(config, :filters)
      assert Map.has_key?(config, :row_actions)
      assert Map.has_key?(config, :bulk_actions)
      assert Map.has_key?(config, :pagination)
      assert Map.has_key?(config, :presentation)
    end

    test "identity section structure" do
      config = ResourceInfo.table_config(Post)

      assert is_map(config.identity)
      assert Map.has_key?(config.identity, :name)
      assert Map.has_key?(config.identity, :route)
    end

    test "source section structure" do
      config = ResourceInfo.table_config(Post)

      assert is_map(config.source)
      assert Map.has_key?(config.source, :actor_key)
      assert Map.has_key?(config.source, :actions)
    end

    test "columns section structure" do
      config = ResourceInfo.table_config(Post)

      assert is_map(config.columns)
      assert Map.has_key?(config.columns, :list)
      assert is_list(config.columns.list)
    end

    test "presentation section structure" do
      config = ResourceInfo.table_config(Post)

      assert is_map(config.presentation)
      assert Map.has_key?(config.presentation, :ui_adapter)
      assert Map.has_key?(config.presentation, :theme)
    end

    test "pagination section structure" do
      config = ResourceInfo.table_config(Post)

      assert is_map(config.pagination)
      assert Map.has_key?(config.pagination, :type)
      assert Map.has_key?(config.pagination, :page_size)
    end
  end

  describe "computed values" do
    test "column_order is persisted" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :column_order)
      assert is_list(config.column_order)
    end

    test "detected_preloads is persisted" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :detected_preloads)
      assert is_list(config.detected_preloads)
    end
  end

  describe "row configuration" do
    test "row section is built" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :row)
    end

    test "selectable is properly set" do
      config = ResourceInfo.table_config(Post)
      assert config.row.selectable == true
    end
  end

  describe "hooks section" do
    test "hooks section exists" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :hooks)
    end

    test "hooks are a map" do
      hooks = ResourceInfo.hooks(Post)
      assert is_map(hooks)
    end
  end

  describe "minimal resource config" do
    test "minimal resource builds valid config" do
      config = ResourceInfo.table_config(MinimalResource)
      assert config != nil
      assert is_map(config)
    end

    test "minimal resource has all sections" do
      config = ResourceInfo.table_config(MinimalResource)

      assert Map.has_key?(config, :identity)
      assert Map.has_key?(config, :columns)
      assert Map.has_key?(config, :pagination)
    end
  end

  describe "Comment resource config" do
    test "Comment config includes preload configuration" do
      config = ResourceInfo.table_config(Comment)
      assert config.source.preload.always == [:user, :post]
    end
  end

  describe "URL sync configuration" do
    test "url_sync section exists when configured" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :url_sync)
    end

    test "url_sync config is built correctly" do
      config = ResourceInfo.url_sync_config(Post)
      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :params)
    end
  end

  describe "refresh configuration" do
    test "refresh section exists when configured" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :refresh)
    end

    test "refresh config is built correctly" do
      config = ResourceInfo.refresh_config(Post)
      assert is_map(config)
    end
  end

  describe "filters configuration" do
    test "filters section is built when defined" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :filters)
    end

    test "filters contain list of filter definitions" do
      filters = ResourceInfo.filters(Post)
      assert is_list(filters)
    end

    test "filter has required fields" do
      filters = ResourceInfo.filters(Post)

      if filters && length(filters) > 0 do
        filter = List.first(filters)
        assert Map.has_key?(filter, :name)
        assert Map.has_key?(filter, :type)
      end
    end

    test "transformed filter config has id_type field" do
      config = ResourceInfo.table_config(Post)

      if config.filters && length(config.filters.list) > 0 do
        filter = List.first(config.filters.list)
        assert Map.has_key?(filter, :id_type)
      end
    end

    test "relation filter in transformed config has id_type set" do
      config = ResourceInfo.table_config(Post)

      if config.filters do
        relation_filter = Enum.find(config.filters.list, &(&1.type == :relation))

        if relation_filter do
          assert relation_filter.id_type != nil
          assert relation_filter.id_type in [:uuid, :uuid_v7, :integer, :string]
        end
      end
    end

    test "non-relation filter in transformed config has nil id_type" do
      config = ResourceInfo.table_config(Post)

      if config.filters do
        non_relation_filter = Enum.find(config.filters.list, &(&1.type != :relation))

        if non_relation_filter do
          assert non_relation_filter.id_type == nil
        end
      end
    end
  end

  describe "row_actions configuration" do
    test "row_actions section is built when defined" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :row_actions)
    end

    test "row_actions contain actions list" do
      config = ResourceInfo.table_config(Post)

      if config.row_actions do
        assert Map.has_key?(config.row_actions, :actions)
        assert is_list(config.row_actions.actions)
      end
    end

    test "action has required fields" do
      config = ResourceInfo.table_config(Post)

      if config.row_actions && length(config.row_actions.actions) > 0 do
        action = List.first(config.row_actions.actions)
        assert Map.has_key?(action, :name)
        assert Map.has_key?(action, :type)
      end
    end
  end

  describe "bulk_actions configuration" do
    test "bulk_actions section exists" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :bulk_actions)
    end

    test "bulk_actions contain enabled flag" do
      config = ResourceInfo.table_config(Post)

      if config.bulk_actions do
        assert Map.has_key?(config.bulk_actions, :enabled)
      end
    end
  end

  describe "realtime configuration" do
    test "realtime section is built" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :realtime)
    end

    test "realtime has enabled flag" do
      config = ResourceInfo.table_config(Post)

      if config.realtime do
        assert Map.has_key?(config.realtime, :enabled)
      end
    end
  end

  describe "multitenancy configuration" do
    test "multitenancy section is built" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config, :multitenancy)
    end

    test "multitenancy has enabled flag" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config.multitenancy, :enabled)
    end

    test "multitenancy has strategy" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config.multitenancy, :strategy)
    end
  end

  describe "complex resource configuration" do
    test "complex resource config is built" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config != nil
    end

    test "complex resource has row_actions with dropdowns" do
      config = ResourceInfo.table_config(ComplexTestResource)

      if config.row_actions do
        assert Map.has_key?(config.row_actions, :dropdowns)
      end
    end

    test "complex resource has realtime with prefix" do
      config = ResourceInfo.table_config(ComplexTestResource)

      if config.realtime && config.realtime.enabled do
        assert config.realtime.prefix != nil
      end
    end
  end

  describe "empty and error states" do
    test "empty_state has message" do
      config = ResourceInfo.table_config(Post)
      assert config.empty_state.message != nil
    end

    test "error_state has message" do
      config = ResourceInfo.table_config(Post)
      assert config.error_state.message != nil
    end

    test "error_state has retry_label" do
      config = ResourceInfo.table_config(Post)
      assert config.error_state.retry_label != nil
    end
  end
end
