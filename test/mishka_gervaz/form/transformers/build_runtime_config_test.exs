defmodule MishkaGervaz.Form.Transformers.BuildRuntimeConfigTest do
  @moduledoc """
  Tests for the BuildRuntimeConfig transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    WizardForm,
    MinimalForm
  }

  describe "FormPost config has all top-level keys" do
    test "config is a map" do
      config = FormInfo.config(FormPost)
      assert is_map(config)
    end

    test "identity key present" do
      config = FormInfo.config(FormPost)
      assert is_map(config.identity)
    end

    test "source key present" do
      config = FormInfo.config(FormPost)
      assert is_map(config.source)
    end

    test "multitenancy key present" do
      config = FormInfo.config(FormPost)
      assert is_map(config.multitenancy)
    end

    test "fields key present" do
      config = FormInfo.config(FormPost)
      assert is_map(config.fields)
      assert is_list(config.fields.list)
    end

    test "groups key present as list" do
      config = FormInfo.config(FormPost)
      assert is_list(config.groups)
    end

    test "layout key present as map" do
      config = FormInfo.config(FormPost)
      assert is_map(config.layout)
    end

    test "uploads key present as list" do
      config = FormInfo.config(FormPost)
      assert is_list(config.uploads)
    end

    test "submit key present as map" do
      config = FormInfo.config(FormPost)
      assert is_map(config.submit)
    end

    test "presentation key present as map" do
      config = FormInfo.config(FormPost)
      assert is_map(config.presentation)
    end

    test "hooks key present as map" do
      config = FormInfo.config(FormPost)
      assert is_map(config.hooks)
    end

    test "detected_preloads key present as list" do
      config = FormInfo.config(FormPost)
      assert is_list(config.detected_preloads)
    end

    test "field_order key present as list" do
      config = FormInfo.config(FormPost)
      assert is_list(config.field_order)
    end
  end

  describe "WizardForm layout steps" do
    test "layout has steps as list" do
      config = FormInfo.config(WizardForm)
      assert is_list(config.layout.steps)
      assert length(config.layout.steps) == 3
    end

    test "step maps have correct keys" do
      config = FormInfo.config(WizardForm)
      step = hd(config.layout.steps)

      assert Map.has_key?(step, :name)
      assert Map.has_key?(step, :groups)
      assert Map.has_key?(step, :action)
      assert Map.has_key?(step, :visible)
      assert Map.has_key?(step, :summary)
      assert Map.has_key?(step, :on_enter)
      assert Map.has_key?(step, :before_leave)
      assert Map.has_key?(step, :after_leave)
      assert Map.has_key?(step, :ui)
    end
  end

  describe "FormPost JS hooks in config" do
    test "hooks map contains js key" do
      config = FormInfo.config(FormPost)
      assert Map.has_key?(config.hooks, :js)
    end

    test "js hooks map has all four keys" do
      config = FormInfo.config(FormPost)
      js = config.hooks.js
      assert Map.has_key?(js, :on_init)
      assert Map.has_key?(js, :after_save)
      assert Map.has_key?(js, :on_cancel)
      assert Map.has_key?(js, :on_error)
    end

    test "js on_init is function/0" do
      config = FormInfo.config(FormPost)
      assert is_function(config.hooks.js.on_init, 0)
    end

    test "js after_save is function/1" do
      config = FormInfo.config(FormPost)
      assert is_function(config.hooks.js.after_save, 1)
    end

    test "js on_cancel is function/0" do
      config = FormInfo.config(FormPost)
      assert is_function(config.hooks.js.on_cancel, 0)
    end

    test "js on_error is function/1" do
      config = FormInfo.config(FormPost)
      assert is_function(config.hooks.js.on_error, 1)
    end
  end

  describe "MinimalForm config" do
    test "groups is nil" do
      config = FormInfo.config(MinimalForm)
      assert config.groups == nil
    end

    test "layout is nil" do
      config = FormInfo.config(MinimalForm)
      assert config.layout == nil
    end

    test "uploads is nil" do
      config = FormInfo.config(MinimalForm)
      assert config.uploads == nil
    end

    test "hooks is nil" do
      config = FormInfo.config(MinimalForm)
      assert config.hooks == nil
    end

    test "js hooks not present when hooks is nil" do
      config = FormInfo.config(MinimalForm)
      assert config.hooks == nil
    end

    test "fields has 1 item" do
      config = FormInfo.config(MinimalForm)
      assert length(config.fields.list) == 1
    end

    test "submit has defaults" do
      config = FormInfo.config(MinimalForm)
      assert config.submit.create_label == "Create"
      assert config.submit.update_label == "Update"
      assert config.submit.cancel_label == "Cancel"
    end
  end
end
