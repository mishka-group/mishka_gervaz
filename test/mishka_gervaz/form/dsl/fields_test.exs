defmodule MishkaGervaz.Form.DSL.FieldsTest do
  @moduledoc """
  Tests for the form fields DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    WizardForm,
    MinimalForm
  }

  describe "field count" do
    test "FormPost has 6 fields" do
      fields = FormInfo.fields(FormPost)
      assert length(fields) == 6
    end

    test "MinimalForm has 1 field" do
      fields = FormInfo.fields(MinimalForm)
      assert length(fields) == 1
    end

    test "WizardForm has 5 fields" do
      fields = FormInfo.fields(WizardForm)
      assert length(fields) == 5
    end
  end

  describe "field lookup by name" do
    test "field/2 returns field map" do
      field = FormInfo.field(FormPost, :title)
      assert field != nil
      assert field.name == :title
    end

    test "field/2 returns nil for non-existent field" do
      assert FormInfo.field(FormPost, :non_existent) == nil
    end
  end

  describe "field types" do
    test "title is :text" do
      field = FormInfo.field(FormPost, :title)
      assert field.type == :text
    end

    test "content is :textarea" do
      field = FormInfo.field(FormPost, :content)
      assert field.type == :textarea
    end

    test "status is :select" do
      field = FormInfo.field(FormPost, :status)
      assert field.type == :select
    end

    test "priority is :number" do
      field = FormInfo.field(FormPost, :priority)
      assert field.type == :number
    end

    test "featured is :toggle" do
      field = FormInfo.field(FormPost, :featured)
      assert field.type == :toggle
    end

    test "metadata is :json" do
      field = FormInfo.field(FormPost, :metadata)
      assert field.type == :json
    end
  end

  describe "field options" do
    test "required field" do
      field = FormInfo.field(FormPost, :title)
      assert field.required == true
    end

    test "default value" do
      field = FormInfo.field(FormPost, :status)
      assert field.default == :draft
    end

    test "min and max" do
      field = FormInfo.field(FormPost, :priority)
      assert field.min == 0
      assert field.max == 100
    end

    test "position" do
      field = FormInfo.field(FormPost, :title)
      assert field.position == :first
    end

    test "include_nil" do
      field = FormInfo.field(FormPost, :status)
      assert field.include_nil == "-- Select --"
    end

    test "options list" do
      field = FormInfo.field(FormPost, :status)

      assert field.options == [
               {:draft, "Draft"},
               {:published, "Published"},
               {:archived, "Archived"}
             ]
    end
  end

  describe "field UI" do
    test "label" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.label == "Post Title"
    end

    test "placeholder" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.placeholder == "Enter title..."
    end

    test "description" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.description == "Main title"
    end

    test "icon" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.icon == "hero-document-text"
    end

    test "class" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.class == "font-bold"
    end

    test "span" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.span == 2
    end

    test "debounce" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.debounce == 300
    end

    test "rows" do
      field = FormInfo.field(FormPost, :content)
      assert field.ui.rows == 10
    end

    test "step (number increment)" do
      field = FormInfo.field(FormPost, :priority)
      assert field.ui.step == 1
    end
  end

  describe "field_order accessor" do
    test "field_order returns list of atom names" do
      order = FormInfo.field_order(FormPost)
      assert is_list(order)
      assert :title in order
      assert :content in order
    end

    test "title appears first due to position: :first" do
      order = FormInfo.field_order(FormPost)
      assert hd(order) == :title
    end
  end

  describe "field default values" do
    test "source defaults to field name" do
      field = FormInfo.field(FormPost, :title)
      assert field.source == :title
    end

    test "visible defaults to true" do
      field = FormInfo.field(FormPost, :content)
      assert field.visible == true
    end

    test "readonly defaults to false" do
      field = FormInfo.field(FormPost, :content)
      assert field.readonly == false
    end

    test "virtual defaults to false" do
      field = FormInfo.field(FormPost, :title)
      assert field.virtual == false
    end

    test "format defaults to nil" do
      field = FormInfo.field(FormPost, :title)
      assert field.format == nil
    end

    test "show_on defaults to nil" do
      field = FormInfo.field(FormPost, :title)
      assert field.show_on == nil
    end

    test "depends_on defaults to nil" do
      field = FormInfo.field(FormPost, :title)
      assert field.depends_on == nil
    end

    test "source defaults to name for content field" do
      field = FormInfo.field(FormPost, :content)
      assert field.source == :content
    end
  end

  describe "field UI nil defaults" do
    test "wrapper_class defaults to nil" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.wrapper_class == nil
    end

    test "autocomplete defaults to nil" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.autocomplete == nil
    end

    test "extra defaults to empty map" do
      field = FormInfo.field(FormPost, :title)
      assert field.ui.extra == %{}
    end
  end

  describe "inline shorthand syntax" do
    test "WizardForm fields use inline syntax correctly" do
      field = FormInfo.field(WizardForm, :title)
      assert field.type == :text
      assert field.required == true
    end

    test "WizardForm toggle field has default" do
      field = FormInfo.field(WizardForm, :featured)
      assert field.type == :toggle
      assert field.default == false
    end

    test "WizardForm number field has min/max" do
      field = FormInfo.field(WizardForm, :priority)
      assert field.type == :number
      assert field.min == 0
      assert field.max == 100
    end
  end
end
