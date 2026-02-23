defmodule MishkaGervaz.Form.DSL.SourceTest do
  @moduledoc """
  Tests for the form source DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    TabsForm,
    MinimalForm,
    NoMasterCheckForm
  }

  describe "actor_key configuration" do
    test "returns configured actor_key" do
      config = FormInfo.config(FormPost)
      assert config.source.actor_key == :current_user
    end

    test "defaults to :current_user when not set" do
      config = FormInfo.config(MinimalForm)
      assert config.source.actor_key == :current_user
    end
  end

  describe "master_check configuration" do
    test "master_check is a function/1" do
      config = FormInfo.config(FormPost)
      assert is_function(config.source.master_check, 1)
    end

    test "master_check returns true for admin user" do
      config = FormInfo.config(FormPost)
      admin_user = %{role: :admin}
      assert config.source.master_check.(admin_user) == true
    end

    test "master_check returns false for regular user" do
      config = FormInfo.config(FormPost)
      regular_user = %{role: :user}
      assert config.source.master_check.(regular_user) == false
    end

    test "master_check returns falsy for nil user" do
      config = FormInfo.config(FormPost)
      refute config.source.master_check.(nil)
    end

    test "default master_check fallback on NoMasterCheckForm" do
      config = FormInfo.config(NoMasterCheckForm)
      assert is_function(config.source.master_check, 1)
    end
  end

  describe "actions configuration" do
    test "create action preserves tuple on FormPost" do
      config = FormInfo.config(FormPost)
      assert config.source.actions.create == {:master_create, :create}
    end

    test "update action preserves tuple on FormPost" do
      config = FormInfo.config(FormPost)
      assert config.source.actions.update == {:master_update, :update}
    end

    test "read action preserves tuple on FormPost" do
      config = FormInfo.config(FormPost)
      assert config.source.actions.read == {:master_get, :read}
    end

    test "plain atoms preserved on TabsForm" do
      config = FormInfo.config(TabsForm)
      assert config.source.actions.create == :create
      assert config.source.actions.update == :update
      assert config.source.actions.read == :read
    end
  end

  describe "preload configuration" do
    test "always preloads configured on FormPost" do
      config = FormInfo.config(FormPost)
      assert :user in config.source.preload.always
    end

    test "master preloads configured on FormPost" do
      config = FormInfo.config(FormPost)
      assert :comments in config.source.preload.master
    end

    test "tenant preloads default to empty" do
      config = FormInfo.config(FormPost)
      assert config.source.preload.tenant == []
    end
  end

  describe "action_for/3" do
    test "returns master action for master user" do
      action = FormInfo.action_for(FormPost, :create, true)
      assert action == :master_create
    end

    test "returns tenant action for tenant user" do
      action = FormInfo.action_for(FormPost, :create, false)
      assert action == :create
    end

    test "returns same action for both when plain atom" do
      master_action = FormInfo.action_for(TabsForm, :create, true)
      tenant_action = FormInfo.action_for(TabsForm, :create, false)
      assert master_action == :create
      assert tenant_action == :create
    end
  end

  describe "source DSL schema defaults" do
    test "actor_key defaults to :current_user" do
      schema = MishkaGervaz.Form.Dsl.Source.schema()
      actor_config = Keyword.get(schema, :actor_key)
      assert Keyword.get(actor_config, :default) == :current_user
    end

    test "master_check has no default" do
      schema = MishkaGervaz.Form.Dsl.Source.schema()
      master_config = Keyword.get(schema, :master_check)
      assert Keyword.get(master_config, :default) == nil
    end
  end
end
