defmodule MishkaGervaz.Transformers.BuildDomainConfigTest do
  @moduledoc """
  Tests for the BuildDomainConfig transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.DomainInfo
  alias MishkaGervaz.Test.Domain

  describe "domain config structure" do
    test "domain config is persisted" do
      config = DomainInfo.domain_config(Domain)
      assert config != nil
      assert is_map(config)
    end

    test "config contains table section" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config, :table)
      assert is_map(config.table)
    end

    test "config contains navigation section when defined" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config, :navigation)
    end
  end

  describe "table section" do
    test "table section contains ui_adapter" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.table, :ui_adapter)
    end

    test "table section contains ui_adapter_opts" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.table, :ui_adapter_opts)
    end

    test "table section contains actor_key" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.table, :actor_key)
    end

    test "table section contains pagination" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.table, :pagination)
    end

    test "table section contains actions" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.table, :actions)
    end
  end

  describe "pagination defaults" do
    test "pagination type is set" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.pagination.type in [:numbered, :infinite, :load_more, :keyset]
    end

    test "pagination page_size is set" do
      config = DomainInfo.domain_config(Domain)
      assert is_integer(config.table.pagination.page_size)
    end

    test "pagination page_size_options defaults to nil when not set" do
      config = DomainInfo.domain_config(Domain)
      assert is_nil(config.table.pagination.page_size_options)
    end
  end

  describe "actions defaults" do
    test "read action is set" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.actions.read != nil
    end

    test "get action is set" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.actions.get != nil
    end

    test "destroy action is set" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.actions.destroy != nil
    end
  end

  describe "navigation section" do
    test "navigation contains menu_groups" do
      config = DomainInfo.domain_config(Domain)

      if config.navigation do
        assert Map.has_key?(config.navigation, :menu_groups)
      end
    end

    test "menu_groups are sorted by position" do
      config = DomainInfo.domain_config(Domain)

      if config.navigation && config.navigation.menu_groups do
        groups = config.navigation.menu_groups
        positions = Enum.map(groups, & &1.position)
        assert positions == Enum.sort(positions)
      end
    end

    test "menu_group contains required fields" do
      config = DomainInfo.domain_config(Domain)

      if config.navigation && config.navigation.menu_groups do
        Enum.each(config.navigation.menu_groups, fn group ->
          assert Map.has_key?(group, :name)
          assert Map.has_key?(group, :label)
          assert Map.has_key?(group, :position)
          assert Map.has_key?(group, :resources)
        end)
      end
    end
  end

  describe "test domain specific values" do
    test "test domain has expected actor_key" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.actor_key == :current_user
    end

    test "test domain has expected pagination" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.pagination.page_size == 20
      assert config.table.pagination.type in [:numbered, :infinite, :load_more, :keyset]
    end

    test "test domain has master_check function" do
      config = DomainInfo.domain_config(Domain)
      assert is_function(config.table.master_check)
    end

    test "test domain has ui_adapter" do
      config = DomainInfo.domain_config(Domain)
      assert config.table.ui_adapter == MishkaGervaz.UIAdapters.Tailwind
    end
  end

  describe "optional sections not defined in Domain" do
    test "realtime section is nil when not defined" do
      config = DomainInfo.domain_config(Domain)
      assert config.table[:realtime] == nil
    end

    test "theme section is nil when not defined" do
      config = DomainInfo.domain_config(Domain)
      assert config.table[:theme] == nil
    end

    test "refresh section is nil when not defined" do
      config = DomainInfo.domain_config(Domain)
      assert config.table[:refresh] == nil
    end

    test "url_sync section is nil when not defined" do
      config = DomainInfo.domain_config(Domain)
      assert config.table[:url_sync] == nil
    end
  end

  describe "domain with navigation" do
    test "navigation menu_groups have expected content" do
      config = DomainInfo.domain_config(Domain)
      groups = config.navigation.menu_groups

      content_group = Enum.find(groups, &(&1.name == :content))
      assert content_group.label == "Content"
      assert content_group.icon == "hero-document-text"
    end
  end
end
