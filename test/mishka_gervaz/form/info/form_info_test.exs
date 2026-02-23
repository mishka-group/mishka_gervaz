defmodule MishkaGervaz.Form.Info.FormInfoTest do
  @moduledoc """
  End-to-end tests for all Info.Form accessors.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    WizardForm,
    TabsForm,
    MinimalForm,
    NoMasterCheckForm,
    SubmitOptionsForm,
    NoButtonsForm
  }

  describe "config/1" do
    test "returns full map for FormPost" do
      config = FormInfo.config(FormPost)
      assert is_map(config)
      assert Map.has_key?(config, :identity)
      assert Map.has_key?(config, :source)
      assert Map.has_key?(config, :fields)
      assert Map.has_key?(config, :groups)
      assert Map.has_key?(config, :layout)
      assert Map.has_key?(config, :uploads)
      assert Map.has_key?(config, :submit)
      assert Map.has_key?(config, :presentation)
      assert Map.has_key?(config, :hooks)
    end
  end

  describe "fields/1" do
    test "returns list for FormPost" do
      fields = FormInfo.fields(FormPost)
      assert is_list(fields)
      assert length(fields) == 6
    end

    test "returns list with 1 field for MinimalForm" do
      fields = FormInfo.fields(MinimalForm)
      assert length(fields) == 1
    end
  end

  describe "field/2" do
    test "returns map for existing field" do
      field = FormInfo.field(FormPost, :title)
      assert is_map(field)
      assert field.name == :title
    end

    test "returns nil for non-existent field" do
      assert FormInfo.field(FormPost, :non_existent) == nil
    end
  end

  describe "field_order/1" do
    test "returns list of atoms" do
      order = FormInfo.field_order(FormPost)
      assert is_list(order)
      assert Enum.all?(order, &is_atom/1)
    end

    test "returns empty list for resource without form field order" do
      order = FormInfo.field_order(MinimalForm)
      assert is_list(order)
    end
  end

  describe "groups/1" do
    test "returns list for FormPost" do
      groups = FormInfo.groups(FormPost)
      assert is_list(groups)
      assert length(groups) == 2
    end

    test "returns empty list for MinimalForm" do
      assert FormInfo.groups(MinimalForm) == []
    end
  end

  describe "uploads/1" do
    test "returns list for FormPost" do
      uploads = FormInfo.uploads(FormPost)
      assert is_list(uploads)
      assert length(uploads) == 1
    end

    test "returns empty list for MinimalForm" do
      assert FormInfo.uploads(MinimalForm) == []
    end
  end

  describe "submit/1" do
    test "returns map with custom labels for FormPost" do
      submit = FormInfo.submit(FormPost)
      assert submit.create.label == "Create Post"
      assert submit.update.label == "Save Post"
      assert submit.cancel.label == "Discard"
    end

    test "returns map with defaults for MinimalForm" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.create.label == "Create"
      assert submit.update.label == "Update"
      assert submit.cancel.label == "Cancel"
      assert submit.cancel != nil
      assert submit.position == :bottom
    end
  end

  describe "layout/1" do
    test "returns map for FormPost" do
      layout = FormInfo.layout(FormPost)
      assert is_map(layout)
      assert layout.mode == :standard
    end

    test "returns nil for MinimalForm" do
      assert FormInfo.layout(MinimalForm) == nil
    end
  end

  describe "steps/1" do
    test "returns list for WizardForm" do
      steps = FormInfo.steps(WizardForm)
      assert is_list(steps)
      assert length(steps) == 3
    end

    test "returns empty list for FormPost" do
      assert FormInfo.steps(FormPost) == []
    end

    test "returns empty list for MinimalForm" do
      assert FormInfo.steps(MinimalForm) == []
    end
  end

  describe "step/2" do
    test "finds by name" do
      step = FormInfo.step(WizardForm, :details)
      assert step.name == :details
    end

    test "returns nil for non-existent step" do
      assert FormInfo.step(WizardForm, :non_existent) == nil
    end
  end

  describe "navigation/1" do
    test "returns :sequential for WizardForm" do
      assert FormInfo.navigation(WizardForm) == :sequential
    end

    test "returns :free for TabsForm" do
      assert FormInfo.navigation(TabsForm) == :free
    end

    test "returns :sequential for MinimalForm (default)" do
      assert FormInfo.navigation(MinimalForm) == :sequential
    end
  end

  describe "persistence/1" do
    test "returns :ets for WizardForm" do
      assert FormInfo.persistence(WizardForm) == :ets
    end

    test "returns :client_token for TabsForm" do
      assert FormInfo.persistence(TabsForm) == :client_token
    end

    test "returns :none for MinimalForm (default)" do
      assert FormInfo.persistence(MinimalForm) == :none
    end
  end

  describe "step_groups/2" do
    test "returns filtered groups for step" do
      groups = FormInfo.step_groups(WizardForm, :details)
      assert length(groups) == 1
      assert hd(groups).name == :basic
    end

    test "returns empty list for non-existent step" do
      assert FormInfo.step_groups(WizardForm, :non_existent) == []
    end

    test "returns empty list for resource without steps" do
      assert FormInfo.step_groups(FormPost, :any) == []
    end
  end

  describe "action_for/3" do
    test "resolves master action for tuple" do
      assert FormInfo.action_for(FormPost, :create, true) == :master_create
    end

    test "resolves tenant action for tuple" do
      assert FormInfo.action_for(FormPost, :create, false) == :create
    end

    test "returns plain atom for both master and tenant" do
      assert FormInfo.action_for(TabsForm, :create, true) == :create
      assert FormInfo.action_for(TabsForm, :create, false) == :create
    end

    test "works for all action types" do
      for action_type <- [:create, :update, :read] do
        master = FormInfo.action_for(FormPost, action_type, true)
        tenant = FormInfo.action_for(FormPost, action_type, false)
        assert is_atom(master)
        assert is_atom(tenant)
      end
    end
  end

  describe "hooks/1" do
    test "returns map for FormPost" do
      hooks = FormInfo.hooks(FormPost)
      assert is_map(hooks)
      assert Map.has_key?(hooks, :on_init)
      assert Map.has_key?(hooks, :before_save)
    end

    test "returns empty map for MinimalForm" do
      assert FormInfo.hooks(MinimalForm) == %{}
    end

    test "includes js sub-map for FormPost" do
      hooks = FormInfo.hooks(FormPost)
      assert Map.has_key?(hooks, :js)
      assert is_map(hooks.js)
    end
  end

  describe "js_hook/2" do
    test "returns function for existing JS hook" do
      func = FormInfo.js_hook(FormPost, :on_init)
      assert is_function(func)
    end

    test "returns nil for non-existent JS hook" do
      result = FormInfo.js_hook(FormPost, :non_existent)
      assert result == nil
    end

    test "returns nil for resource without JS hooks" do
      result = FormInfo.js_hook(MinimalForm, :on_init)
      assert result == nil
    end

    test "on_init JS hook returns JS struct" do
      func = FormInfo.js_hook(FormPost, :on_init)
      result = func.()
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "on_cancel JS hook returns JS struct" do
      func = FormInfo.js_hook(FormPost, :on_cancel)
      result = func.(nil)
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "after_save JS hook returns JS struct" do
      func = FormInfo.js_hook(FormPost, :after_save)
      result = func.(nil)
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "on_error JS hook returns JS struct" do
      func = FormInfo.js_hook(FormPost, :on_error)
      result = func.(nil)
      assert is_struct(result, Phoenix.LiveView.JS)
    end
  end

  describe "detected_preloads/1" do
    test "returns list" do
      preloads = FormInfo.detected_preloads(FormPost)
      assert is_list(preloads)
    end

    test "returns empty list for MinimalForm" do
      preloads = FormInfo.detected_preloads(MinimalForm)
      assert is_list(preloads)
    end
  end

  describe "all_preloads/2" do
    test "includes always preloads for master" do
      preloads = FormInfo.all_preloads(FormPost, true)
      assert :user in preloads
    end

    test "includes master preloads for master user" do
      preloads = FormInfo.all_preloads(FormPost, true)
      assert :comments in preloads
    end

    test "does not include master preloads for tenant user" do
      preloads = FormInfo.all_preloads(FormPost, false)
      refute :comments in preloads
    end

    test "includes always preloads for tenant" do
      preloads = FormInfo.all_preloads(FormPost, false)
      assert :user in preloads
    end

    test "returns detected preloads for MinimalForm" do
      preloads = FormInfo.all_preloads(MinimalForm, false)
      assert is_list(preloads)
    end
  end

  describe "stream_name/1" do
    test "returns atom for FormPost" do
      assert FormInfo.stream_name(FormPost) == :form_post_stream
    end

    test "returns auto-derived name for MinimalForm" do
      name = FormInfo.stream_name(MinimalForm)
      assert is_atom(name)
      assert name != nil
    end
  end

  describe "route/1" do
    test "returns string for FormPost" do
      assert FormInfo.route(FormPost) == "/admin/posts"
    end

    test "returns nil for MinimalForm" do
      assert FormInfo.route(MinimalForm) == nil
    end
  end

  describe "component_id/1" do
    test "returns string for FormPost" do
      assert FormInfo.component_id(FormPost) == "form_post"
    end

    test "returns string for SubmitOptionsForm" do
      assert FormInfo.component_id(SubmitOptionsForm) == "submit_options_form"
    end
  end

  describe "submit/1 per-button structure" do
    test "SubmitOptionsForm create button has restricted true" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.create.restricted == true
    end

    test "SubmitOptionsForm update button has function-based options" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert is_function(submit.update.disabled, 1)
      assert is_function(submit.update.restricted, 1)
      assert is_function(submit.update.visible, 1)
    end

    test "SubmitOptionsForm cancel button visible is false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.cancel.visible == false
    end

    test "NoButtonsForm all buttons are nil" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.create == nil
      assert submit.update == nil
      assert submit.cancel == nil
    end

    test "NoButtonsForm still has position" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.position == :bottom
    end
  end
end
