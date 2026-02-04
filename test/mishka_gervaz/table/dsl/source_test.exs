defmodule MishkaGervaz.DSL.SourceTest do
  @moduledoc """
  Tests for the source DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo

  alias MishkaGervaz.Test.Resources.{
    Post,
    Comment,
    User,
    MinimalResource,
    DslOverrideResource,
    ArchivableResource
  }

  describe "actor_key configuration" do
    test "returns configured actor_key" do
      config = ResourceInfo.table_config(Post)
      assert config.source.actor_key == :current_user
    end
  end

  describe "master_check configuration" do
    test "master_check is a function" do
      config = ResourceInfo.table_config(Post)
      assert is_function(config.source.master_check, 1)
    end

    test "master_check returns true for admin user" do
      config = ResourceInfo.table_config(Post)
      admin_user = %{role: :admin}
      assert config.source.master_check.(admin_user) == true
    end

    test "master_check returns false for regular user" do
      config = ResourceInfo.table_config(Post)
      regular_user = %{role: :user}
      assert config.source.master_check.(regular_user) == false
    end

    test "master_check returns falsy for nil user" do
      config = ResourceInfo.table_config(Post)
      # master_check returns nil or false for nil user
      refute config.source.master_check.(nil)
    end
  end

  describe "actions configuration" do
    test "read action preserves developer tuple for non-multi-tenant" do
      config = ResourceInfo.table_config(Post)
      assert config.source.actions.read == {:master_read, :tenant_read}
    end

    test "destroy action preserves developer tuple for non-multi-tenant" do
      config = ResourceInfo.table_config(Post)
      assert config.source.actions.destroy == {:destroy, :destroy}
    end

    test "action_for returns master action for master user" do
      action = ResourceInfo.get_action(Post, :read, true)
      assert action == :master_read
    end

    test "action_for returns tenant action for tenant user" do
      action = ResourceInfo.get_action(Post, :read, false)
      assert action == :tenant_read
    end

    test "action_for with destroy actions" do
      master_action = ResourceInfo.get_action(Post, :destroy, true)
      tenant_action = ResourceInfo.get_action(Post, :destroy, false)
      assert master_action == :destroy
      assert tenant_action == :destroy
    end
  end

  describe "preload configuration" do
    test "always preloads are configured" do
      config = ResourceInfo.table_config(Post)
      assert :user in config.source.preload.always
    end

    test "all_preloads includes always preloads for master" do
      preloads = ResourceInfo.all_preloads(Post, true)
      assert :user in preloads
    end

    test "all_preloads includes always preloads for tenant" do
      preloads = ResourceInfo.all_preloads(Post, false)
      assert :user in preloads
    end

    test "Comment resource has multiple always preloads" do
      config = ResourceInfo.table_config(Comment)
      assert :user in config.source.preload.always
      assert :post in config.source.preload.always
    end
  end

  describe "detected_preloads" do
    test "detected_preloads are extracted from column sources" do
      preloads = ResourceInfo.detected_preloads(Post)
      # The user column has source [:user, :name], so :user should be detected
      assert is_list(preloads)
    end

    test "all_preloads combines always and detected preloads" do
      preloads = ResourceInfo.all_preloads(Post, true)
      assert is_list(preloads)
      # Should include manually configured preloads
      assert :user in preloads
    end
  end

  describe "system defaults (no DSL source section)" do
    test "non-tenant resource uses single atom defaults" do
      config = ResourceInfo.table_config(MinimalResource)

      assert config.source.actions.read == :read
      assert config.source.actions.get == :get
      assert config.source.actions.destroy == :destroy
    end

    test "multitenancy is disabled for MinimalResource" do
      config = ResourceInfo.table_config(MinimalResource)
      assert config.multitenancy.enabled == false
    end

    test "get_action returns same action for master and tenant" do
      master_read = ResourceInfo.get_action(MinimalResource, :read, true)
      tenant_read = ResourceInfo.get_action(MinimalResource, :read, false)

      assert master_read == :read
      assert tenant_read == :read
    end

    test "get_action works for all action types with single atoms" do
      for action_type <- [:read, :get, :destroy] do
        master = ResourceInfo.get_action(MinimalResource, action_type, true)
        tenant = ResourceInfo.get_action(MinimalResource, action_type, false)

        assert master == tenant
        assert is_atom(master)
      end
    end

    test "actor_key defaults to :current_user for MinimalResource" do
      config = ResourceInfo.table_config(MinimalResource)
      assert config.source.actor_key == :current_user
    end

    test "preloads are empty by default" do
      config = ResourceInfo.table_config(MinimalResource)

      assert config.source.preload.always == []
      assert config.source.preload.master == []
      assert config.source.preload.tenant == []
    end
  end

  describe "DSL explicit config with DslOverrideResource" do
    test "all DSL action tuples are preserved" do
      config = ResourceInfo.table_config(DslOverrideResource)

      assert config.source.actions.read == {:custom_master, :custom_tenant}
      assert config.source.actions.get == {:custom_master_get, :custom_get}
      assert config.source.actions.destroy == {:custom_master_destroy, :custom_destroy}
    end

    test "get_action resolves all action types correctly" do
      master_get = ResourceInfo.get_action(DslOverrideResource, :get, true)
      tenant_get = ResourceInfo.get_action(DslOverrideResource, :get, false)

      assert master_get == :custom_master_get
      assert tenant_get == :custom_get

      master_read = ResourceInfo.get_action(DslOverrideResource, :read, true)
      tenant_read = ResourceInfo.get_action(DslOverrideResource, :read, false)

      assert master_read == :custom_master
      assert tenant_read == :custom_tenant

      master_destroy = ResourceInfo.get_action(DslOverrideResource, :destroy, true)
      tenant_destroy = ResourceInfo.get_action(DslOverrideResource, :destroy, false)

      assert master_destroy == :custom_master_destroy
      assert tenant_destroy == :custom_destroy
    end
  end

  describe "DSL vs system defaults comparison" do
    test "User (no source section) uses system defaults" do
      config = ResourceInfo.table_config(User)

      assert config.source.actions.read == :read
      assert config.multitenancy.enabled == false
    end

    test "Post (explicit DSL) uses developer config" do
      config = ResourceInfo.table_config(Post)

      assert config.source.actions.read == {:master_read, :tenant_read}
      assert config.multitenancy.enabled == false
    end

    test "DslOverrideResource (explicit DSL) uses developer config" do
      config = ResourceInfo.table_config(DslOverrideResource)

      assert config.source.actions.read == {:custom_master, :custom_tenant}
    end
  end

  describe "archive configuration" do
    test "archive enabled key is configured" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.enabled == true
    end

    test "archive restricted key is configured" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.restricted == true
    end

    test "archive read_action key is configured with tuple" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.actions.read == {:master_archived, :archived}
    end

    test "archive get_action key is configured with tuple" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.actions.get == {:master_get_archived, :get_archived}
    end

    test "archive restore_action key is configured with tuple" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.actions.restore == {:master_unarchive, :unarchive}
    end

    test "archive destroy_action key is configured with tuple" do
      config = ResourceInfo.table_config(ArchivableResource)

      assert config.source.archive.actions.destroy ==
               {:master_permanent_destroy, :permanent_destroy}
    end
  end

  describe "archive via TableInfo" do
    test "TableInfo.archive_enabled?/1 returns true for archivable resource" do
      assert TableInfo.archive_enabled?(ArchivableResource) == true
    end

    test "TableInfo.archive_enabled?/1 returns false for non-archivable resource" do
      assert TableInfo.archive_enabled?(Post) == false
    end

    test "TableInfo.archive_action_for/3 returns correct actions" do
      master_read = TableInfo.archive_action_for(ArchivableResource, :read, true)
      tenant_read = TableInfo.archive_action_for(ArchivableResource, :read, false)

      assert master_read == :master_archived
      assert tenant_read == :archived
    end

    test "TableInfo.archive_action_for/3 returns nil for non-archivable" do
      assert TableInfo.archive_action_for(Post, :read, true) == nil
    end
  end

  describe "source DSL schema defaults" do
    test "actor_key defaults to :current_user in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Source.schema()
      actor_config = Keyword.get(schema, :actor_key)
      assert Keyword.get(actor_config, :default) == :current_user
    end

    test "master_check has no default in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Source.schema()
      master_config = Keyword.get(schema, :master_check)
      assert Keyword.get(master_config, :default) == nil
    end
  end
end
