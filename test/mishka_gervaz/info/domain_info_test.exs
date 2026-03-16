defmodule MishkaGervaz.Info.DomainInfoTest do
  @moduledoc """
  Tests for the DomainInfo introspection module with strict value assertions.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.DomainInfo
  alias MishkaGervaz.Test.Domain

  describe "domain_config/1" do
    test "returns full config with all expected top-level keys" do
      config = DomainInfo.domain_config(Domain)

      assert Map.has_key?(config, :table)
      assert Map.has_key?(config, :navigation)
    end

    test "config table section has expected structure" do
      config = DomainInfo.domain_config(Domain)

      # Defined sections
      assert Map.has_key?(config.table, :pagination)
      assert Map.has_key?(config.table, :ui_adapter)
      assert Map.has_key?(config.table, :actor_key)

      # Undefined sections return nil
      assert Map.has_key?(config.table, :realtime)
      assert config.table.realtime == nil
      assert Map.has_key?(config.table, :theme)
      assert config.table.theme == nil
      assert Map.has_key?(config.table, :refresh)
      assert config.table.refresh == nil
      assert Map.has_key?(config.table, :url_sync)
      assert config.table.url_sync == nil
    end

    test "config navigation section has expected menu groups" do
      config = DomainInfo.domain_config(Domain)

      assert length(config.navigation.menu_groups) == 2
    end
  end

  describe "defaults/1" do
    test "returns defaults with pagination map" do
      defaults = DomainInfo.defaults(Domain)

      assert is_map(defaults.pagination)
      assert Map.has_key?(defaults.pagination, :page_size)
      assert Map.has_key?(defaults.pagination, :type)
    end

    test "returns defaults with exact ui_adapter" do
      defaults = DomainInfo.defaults(Domain)

      assert defaults.ui_adapter == MishkaGervaz.UIAdapters.Tailwind
    end

    test "returns defaults with actor_key" do
      defaults = DomainInfo.defaults(Domain)

      assert defaults.actor_key == :current_user
    end

    test "returns nil for realtime when not defined in domain" do
      defaults = DomainInfo.defaults(Domain)

      assert defaults.realtime == nil
    end

    test "returns nil for theme when not defined in domain" do
      defaults = DomainInfo.defaults(Domain)

      assert defaults.theme == nil
    end

    test "returns nil for refresh when not defined in domain" do
      defaults = DomainInfo.defaults(Domain)

      assert defaults.refresh == nil
    end

    test "returns nil for url_sync when not defined in domain" do
      defaults = DomainInfo.defaults(Domain)

      assert defaults.url_sync == nil
    end
  end

  describe "navigation/1" do
    test "returns navigation with exact menu_groups count" do
      nav = DomainInfo.navigation(Domain)

      assert length(nav.menu_groups) == 2
    end

    test "navigation contains content menu group with correct properties" do
      nav = DomainInfo.navigation(Domain)
      content_group = Enum.find(nav.menu_groups, &(&1.name == :content))

      assert content_group != nil
      assert content_group.name == :content
      assert content_group.label == "Content"
      assert content_group.icon == "hero-document-text"
    end

    test "navigation contains users menu group with correct properties" do
      nav = DomainInfo.navigation(Domain)
      users_group = Enum.find(nav.menu_groups, &(&1.name == :users))

      assert users_group != nil
      assert users_group.name == :users
      assert users_group.label == "Users"
      assert users_group.icon == "hero-users"
    end
  end

  describe "menu_groups/1" do
    test "returns exactly 2 menu groups" do
      groups = DomainInfo.menu_groups(Domain)

      assert length(groups) == 2
    end

    test "content menu group has all expected keys" do
      groups = DomainInfo.menu_groups(Domain)
      content_group = Enum.find(groups, &(&1.name == :content))

      assert content_group.name == :content
      assert content_group.label == "Content"
      assert content_group.icon == "hero-document-text"
      assert Map.has_key?(content_group, :position)
      assert Map.has_key?(content_group, :resources)
      assert Map.has_key?(content_group, :visible)
    end

    test "users menu group has all expected keys" do
      groups = DomainInfo.menu_groups(Domain)
      users_group = Enum.find(groups, &(&1.name == :users))

      assert users_group.name == :users
      assert users_group.label == "Users"
      assert users_group.icon == "hero-users"
    end

    test "menu groups are returned in order" do
      groups = DomainInfo.menu_groups(Domain)
      group_names = Enum.map(groups, & &1.name)

      assert group_names == [:content, :users]
    end
  end

  describe "default_ui_adapter/1" do
    test "returns exact Tailwind adapter module" do
      adapter = DomainInfo.default_ui_adapter(Domain)

      assert adapter == MishkaGervaz.UIAdapters.Tailwind
    end
  end

  describe "default_pagination/1" do
    test "returns pagination map with expected keys" do
      pagination = DomainInfo.default_pagination(Domain)

      assert Map.has_key?(pagination, :page_size)
      assert Map.has_key?(pagination, :type)
      assert Map.has_key?(pagination, :page_size_options)
    end

    test "pagination page_size is 20" do
      pagination = DomainInfo.default_pagination(Domain)

      assert pagination.page_size == 20
    end

    test "pagination type is numbered (set in domain)" do
      pagination = DomainInfo.default_pagination(Domain)

      # Domain sets type: :numbered
      assert pagination.type == :numbered
    end

    test "pagination page_size_options defaults to nil" do
      pagination = DomainInfo.default_pagination(Domain)

      assert pagination.page_size_options == nil
    end
  end

  describe "default_realtime/1" do
    test "returns nil when realtime not defined in domain" do
      realtime = DomainInfo.default_realtime(Domain)

      assert realtime == nil
    end
  end

  describe "default_theme/1" do
    test "returns nil when theme not defined in domain" do
      theme = DomainInfo.default_theme(Domain)

      assert theme == nil
    end
  end

  describe "default_refresh/1" do
    test "returns nil when refresh not defined in domain" do
      refresh = DomainInfo.default_refresh(Domain)

      assert refresh == nil
    end
  end

  describe "default_url_sync/1" do
    test "returns nil when url_sync not defined in domain" do
      url_sync = DomainInfo.default_url_sync(Domain)

      assert url_sync == nil
    end
  end
end
