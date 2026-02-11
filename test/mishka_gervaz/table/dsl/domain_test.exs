defmodule MishkaGervaz.DSL.DomainTest do
  @moduledoc """
  Tests for the Domain DSL extension.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.DomainInfo
  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Domain
  alias MishkaGervaz.Test.Resources.{Post, MinimalResource}

  describe "domain configuration" do
    test "domain config is present" do
      config = DomainInfo.domain_config(Domain)
      assert config != nil
    end

    test "defaults are configured" do
      defaults = DomainInfo.defaults(Domain)
      assert is_map(defaults)
    end
  end

  describe "domain defaults" do
    test "default pagination is configured" do
      pagination = DomainInfo.default_pagination(Domain)
      assert pagination != nil
      assert pagination.page_size == 20
      # Check that type is one of the valid pagination types
      assert pagination.type in [:numbered, :infinite, :load_more, :keyset]
    end

    test "default ui_adapter is configured" do
      adapter = DomainInfo.default_ui_adapter(Domain)
      assert adapter == MishkaGervaz.UIAdapters.Tailwind
    end
  end

  describe "domain defaults inheritance" do
    test "domain pagination type is :numbered" do
      pagination = DomainInfo.default_pagination(Domain)
      assert pagination.type == :numbered
    end

    test "domain pagination page_size is 20" do
      pagination = DomainInfo.default_pagination(Domain)
      assert pagination.page_size == 20
    end

    test "resource without pagination uses domain pagination type" do
      config = ResourceInfo.table_config(MinimalResource)
      domain_pagination = DomainInfo.default_pagination(Domain)

      assert config.pagination.type == domain_pagination.type
      assert config.pagination.type == :numbered
    end

    test "resource without pagination uses domain pagination page_size" do
      config = ResourceInfo.table_config(MinimalResource)
      domain_pagination = DomainInfo.default_pagination(Domain)

      assert config.pagination.page_size == domain_pagination.page_size
    end

    test "resource with explicit pagination overrides domain defaults" do
      config = ResourceInfo.table_config(Post)
      domain_pagination = DomainInfo.default_pagination(Domain)

      # Post has type: :infinite, domain has type: :numbered
      assert config.pagination.type == :infinite
      refute config.pagination.type == domain_pagination.type

      # Post has page_size: 25, domain has page_size: 20
      assert config.pagination.page_size == 25
      refute config.pagination.page_size == domain_pagination.page_size
    end
  end

  describe "navigation" do
    test "navigation config is present" do
      navigation = DomainInfo.navigation(Domain)
      assert is_map(navigation)
    end

    test "menu_groups are configured" do
      groups = DomainInfo.menu_groups(Domain)
      assert is_list(groups)
      assert length(groups) >= 1
    end

    test "content menu group exists" do
      groups = DomainInfo.menu_groups(Domain)
      content_group = Enum.find(groups, &(&1.name == :content))
      assert content_group != nil
      assert content_group.label == "Content"
      assert content_group.icon == "hero-document-text"
    end

    test "users menu group exists" do
      groups = DomainInfo.menu_groups(Domain)
      users_group = Enum.find(groups, &(&1.name == :users))
      assert users_group != nil
      assert users_group.label == "Users"
      assert users_group.icon == "hero-users"
    end
  end
end
