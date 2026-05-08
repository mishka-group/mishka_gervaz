defmodule MishkaGervaz.Form.Transformers.MergeDefaultsTest do
  @moduledoc """
  Tests for the MergeDefaults transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias Spark.Dsl.Extension

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    MinimalForm,
    NoMasterCheckForm
  }

  describe "MinimalForm identity auto-derivation" do
    test "name is auto-derived from module" do
      config = FormInfo.config(MinimalForm)
      assert is_atom(config.identity.name)
      assert config.identity.name != nil
    end

    test "stream_name is auto-derived from name" do
      config = FormInfo.config(MinimalForm)
      name = config.identity.name
      assert config.identity.stream_name == String.to_atom("#{name}_stream")
    end
  end

  describe "default master_check MFA" do
    test "default master_check is persisted when not set" do
      persisted =
        Extension.get_persisted(
          NoMasterCheckForm,
          :mishka_gervaz_form_default_master_check
        )

      assert is_tuple(persisted)
      assert elem(persisted, 0) == MishkaGervaz.Helpers
      assert elem(persisted, 1) == :master_user?
    end

    test "resolved master_check is a function on NoMasterCheckForm" do
      config = FormInfo.config(NoMasterCheckForm)
      assert is_function(config.source.master_check, 1)
    end
  end

  describe "actor_key defaults" do
    test "defaults to :current_user when not explicitly set" do
      config = FormInfo.config(MinimalForm)
      assert config.source.actor_key == :current_user
    end
  end

  describe "domain inheritance — MinimalForm has no overrides, inherits from Test.Domain" do
    test "inherits actor_key" do
      assert FormInfo.config(MinimalForm).source.actor_key == :current_user
    end

    test "inherits master_check as a function/1" do
      check = FormInfo.config(MinimalForm).source.master_check
      assert is_function(check, 1)
    end

    test "inherits actions.create" do
      assert FormInfo.config(MinimalForm).source.actions.create ==
               {:master_create, :create}
    end

    test "inherits actions.update" do
      assert FormInfo.config(MinimalForm).source.actions.update ==
               {:master_update, :update}
    end

    test "inherits actions.read" do
      assert FormInfo.config(MinimalForm).source.actions.read ==
               {:master_get, :read}
    end

    test "inherits presentation.template" do
      assert FormInfo.config(MinimalForm).presentation.template ==
               MishkaGervaz.Form.Templates.Standard
    end

    test "inherits presentation.features" do
      assert FormInfo.config(MinimalForm).presentation.features == :all
    end

    test "inherits ui_adapter (Tailwind)" do
      adapter = FormInfo.config(MinimalForm).presentation.ui_adapter
      assert adapter == MishkaGervaz.UIAdapters.Tailwind
    end
  end

  describe "resource override — FormPost wins per key when both resource and domain are set" do
    test "FormPost overrides actor_key" do
      assert FormInfo.config(FormPost).source.actor_key == :current_user
    end

    test "FormPost overrides master_check (still its own function)" do
      check = FormInfo.config(FormPost).source.master_check
      assert is_function(check, 1)
    end

    test "FormPost preserves its identity.name (no auto-derivation)" do
      assert FormInfo.config(FormPost).identity.name == :form_post
    end

    test "FormPost preserves its identity.stream_name (no auto-derivation)" do
      assert FormInfo.config(FormPost).identity.stream_name == :form_post_stream
    end

    test "FormPost preserves its actions.create" do
      assert FormInfo.config(FormPost).source.actions.create ==
               {:master_create, :create}
    end
  end

  describe "identity auto-derivation precedence" do
    test "MinimalForm name is auto-derived to a snake_case form atom" do
      name = FormInfo.config(MinimalForm).identity.name
      # The transformer derives via module_to_snake/2 with "_form" suffix.
      assert is_atom(name)
      assert name |> Atom.to_string() |> String.ends_with?("_form")
    end

    test "MinimalForm stream_name is derived as <name>_stream" do
      config = FormInfo.config(MinimalForm)

      assert config.identity.stream_name ==
               String.to_atom("#{config.identity.name}_stream")
    end
  end
end
