defmodule MishkaGervaz.Form.DSL.PresentationTest do
  @moduledoc """
  Tests for the form presentation and submit DSL sections.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    MinimalForm
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
    test "create_label" do
      submit = FormInfo.submit(FormPost)
      assert submit.create_label == "Create Post"
    end

    test "update_label" do
      submit = FormInfo.submit(FormPost)
      assert submit.update_label == "Save Post"
    end

    test "cancel_label" do
      submit = FormInfo.submit(FormPost)
      assert submit.cancel_label == "Discard"
    end

    test "show_cancel" do
      submit = FormInfo.submit(FormPost)
      assert submit.show_cancel == true
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
    test "create_label defaults to Create" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.create_label == "Create"
    end

    test "update_label defaults to Update" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.update_label == "Update"
    end

    test "cancel_label defaults to Cancel" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.cancel_label == "Cancel"
    end

    test "show_cancel defaults to true" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.show_cancel == true
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
