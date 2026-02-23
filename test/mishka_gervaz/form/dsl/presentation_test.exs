defmodule MishkaGervaz.Form.DSL.PresentationTest do
  @moduledoc """
  Tests for the form presentation and submit DSL sections.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    MinimalForm,
    SubmitOptionsForm,
    NoButtonsForm
  }

  describe "FormPost presentation" do
    test "features is :all" do
      config = FormInfo.config(FormPost)
      assert config.presentation.features == :all
    end

    test "theme form_class" do
      config = FormInfo.config(FormPost)
      assert config.presentation.theme.form_class == "max-w-4xl"
    end

    test "theme field_class" do
      config = FormInfo.config(FormPost)
      assert config.presentation.theme.field_class == "rounded-md"
    end

    test "theme label_class" do
      config = FormInfo.config(FormPost)
      assert config.presentation.theme.label_class == "text-sm font-medium"
    end

    test "theme error_class" do
      config = FormInfo.config(FormPost)
      assert config.presentation.theme.error_class == "text-red-600"
    end

    test "theme extra" do
      config = FormInfo.config(FormPost)
      assert config.presentation.theme.extra == %{variant: :default}
    end
  end

  describe "FormPost submit" do
    test "create button label" do
      submit = FormInfo.submit(FormPost)
      assert submit.create.label == "Create Post"
    end

    test "update button label" do
      submit = FormInfo.submit(FormPost)
      assert submit.update.label == "Save Post"
    end

    test "cancel button label" do
      submit = FormInfo.submit(FormPost)
      assert submit.cancel.label == "Discard"
    end

    test "cancel button exists (replaces show_cancel)" do
      submit = FormInfo.submit(FormPost)
      assert submit.cancel != nil
    end

    test "position" do
      submit = FormInfo.submit(FormPost)
      assert submit.position == :bottom
    end

    test "submit UI submit_class" do
      submit = FormInfo.submit(FormPost)
      assert submit.ui.submit_class == "bg-blue-600 text-white"
    end

    test "submit UI cancel_class" do
      submit = FormInfo.submit(FormPost)
      assert submit.ui.cancel_class == "bg-gray-200"
    end

    test "submit UI wrapper_class" do
      submit = FormInfo.submit(FormPost)
      assert submit.ui.wrapper_class == "flex gap-4"
    end

    test "submit UI extra" do
      submit = FormInfo.submit(FormPost)
      assert submit.ui.extra == %{rounded: true}
    end
  end

  describe "MinimalForm submit defaults" do
    test "create button label defaults to Create" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.create.label == "Create"
    end

    test "update button label defaults to Update" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.update.label == "Update"
    end

    test "cancel button label defaults to Cancel" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.cancel.label == "Cancel"
    end

    test "all buttons present by default" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.create != nil
      assert submit.update != nil
      assert submit.cancel != nil
    end

    test "position defaults to :bottom" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.position == :bottom
    end

    test "ui defaults to nil" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.ui == nil
    end
  end

  describe "FormPost presentation additional keys" do
    test "template inherits domain default when not set on resource" do
      config = FormInfo.config(FormPost)
      assert config.presentation.template == MishkaGervaz.Form.Templates.Standard
    end

    test "ui_adapter defaults to nil" do
      config = FormInfo.config(FormPost)
      assert config.presentation.ui_adapter == nil
    end

    test "ui_adapter_opts defaults to empty list" do
      config = FormInfo.config(FormPost)
      assert config.presentation.ui_adapter_opts == []
    end
  end

  describe "SubmitOptionsForm per-button options (inline + block)" do
    test "create button label" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.create.label == "Create Item"
    end

    test "create button disabled is false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.create.disabled == false
    end

    test "create button restricted is true (inline)" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.create.restricted == true
    end

    test "create button visible defaults to true" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.create.visible == true
    end

    test "update button label (block syntax)" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.update.label == "Save Item"
    end

    test "update button disabled is function" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert is_function(submit.update.disabled, 1)
    end

    test "update button restricted is function" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert is_function(submit.update.restricted, 1)
    end

    test "update button visible is function" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert is_function(submit.update.visible, 1)
    end

    test "update button disabled function returns false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.update.disabled.(%{}) == false
    end

    test "update button restricted function returns false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.update.restricted.(%{}) == false
    end

    test "update button visible function returns true" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.update.visible.(%{}) == true
    end

    test "cancel button label (inline)" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.cancel.label == "Go Back"
    end

    test "cancel button visible is false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.cancel.visible == false
    end

    test "cancel button disabled defaults to false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.cancel.disabled == false
    end

    test "cancel button restricted defaults to false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.cancel.restricted == false
    end

    test "position is :top" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.position == :top
    end
  end

  describe "NoButtonsForm — empty submit block" do
    test "all buttons are nil" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.create == nil
      assert submit.update == nil
      assert submit.cancel == nil
    end

    test "position still works" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.position == :bottom
    end

    test "ui is nil" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.ui == nil
    end
  end

  describe "FormPost default button options" do
    test "create button disabled defaults to false" do
      submit = FormInfo.submit(FormPost)
      assert submit.create.disabled == false
    end

    test "create button restricted defaults to false" do
      submit = FormInfo.submit(FormPost)
      assert submit.create.restricted == false
    end

    test "create button visible defaults to true" do
      submit = FormInfo.submit(FormPost)
      assert submit.create.visible == true
    end

    test "update button disabled defaults to false" do
      submit = FormInfo.submit(FormPost)
      assert submit.update.disabled == false
    end

    test "cancel button disabled defaults to false" do
      submit = FormInfo.submit(FormPost)
      assert submit.cancel.disabled == false
    end
  end

  describe "info accessors" do
    test "FormInfo.submit/1 returns map" do
      submit = FormInfo.submit(FormPost)
      assert is_map(submit)
    end

    test "FormInfo.layout/1 returns map for FormPost" do
      layout = FormInfo.layout(FormPost)
      assert is_map(layout)
    end

    test "FormInfo.layout/1 returns nil for MinimalForm" do
      assert FormInfo.layout(MinimalForm) == nil
    end
  end
end
