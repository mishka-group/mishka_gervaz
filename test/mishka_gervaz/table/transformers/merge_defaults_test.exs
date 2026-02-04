defmodule MishkaGervaz.Transformers.MergeDefaultsTest do
  @moduledoc """
  Tests for the MergeDefaults transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.DomainInfo
  alias MishkaGervaz.Test.Domain
  alias MishkaGervaz.Test.Resources.{Post, User, MinimalResource}

  describe "domain defaults inheritance" do
    test "resources inherit ui_adapter from domain" do
      domain_adapter = DomainInfo.default_ui_adapter(Domain)
      config = ResourceInfo.table_config(User)

      assert config.presentation.ui_adapter == domain_adapter
    end

    test "resources can override domain defaults" do
      # Post explicitly sets ui_adapter
      config = ResourceInfo.table_config(Post)
      assert config.presentation.ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
    end
  end

  describe "identity defaults" do
    test "identity name is set" do
      config = ResourceInfo.table_config(Post)
      assert config.identity.name == :posts
    end

    test "stream_name is auto-generated when not set" do
      stream_name = ResourceInfo.stream_name(Post)
      assert is_atom(stream_name)
    end

    test "route can be set explicitly" do
      config = ResourceInfo.table_config(Post)
      assert config.identity.route == "/admin/posts"
    end
  end

  describe "minimal resource defaults" do
    test "minimal resource gets sensible defaults" do
      config = ResourceInfo.table_config(MinimalResource)
      assert config != nil
      assert config.identity != nil
      assert config.identity.name == :minimal
    end

    test "minimal resource inherits domain pagination" do
      config = ResourceInfo.table_config(MinimalResource)
      # Pagination should be inherited from domain or have defaults
      assert config.pagination != nil
    end
  end

  describe "source defaults" do
    test "actor_key is inherited from domain" do
      config = ResourceInfo.table_config(User)
      assert config.source.actor_key == :current_user
    end

    test "actor_key defaults to :current_user" do
      config = ResourceInfo.table_config(Post)
      assert config.source.actor_key == :current_user
    end
  end

  describe "tenant defaults" do
    test "default_master_check is persisted" do
      # The default master_check function should be persisted
      config = ResourceInfo.table_config(Post)

      assert config.source.master_check != nil or
               Spark.Dsl.Extension.get_persisted(Post, :mishka_gervaz_default_master_check) != nil
    end
  end

  describe "pagination defaults" do
    test "pagination inherits from domain" do
      config = ResourceInfo.table_config(User)
      domain_pagination = DomainInfo.default_pagination(Domain)

      assert config.pagination.page_size == domain_pagination.page_size
    end

    test "pagination has page_size_options" do
      config = ResourceInfo.table_config(Post)
      assert is_list(config.pagination.page_size_options)
    end
  end
end
