defmodule MishkaGervaz.Form.Types.Field.NestedTest do
  @moduledoc """
  Tests for the nested field type, embedded resource detection, and rich sub-field inference.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Nested
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.NestedForm

  describe "type module behaviour" do
    test "render returns assigns unchanged" do
      assigns = %{some: :data}
      assert Nested.render(assigns, %{}) == assigns
    end

    test "validate accepts any value" do
      assert {:ok, %{"name" => "test"}} = Nested.validate(%{"name" => "test"}, %{})
    end

    test "validate accepts a list" do
      assert {:ok, [%{name: "a"}]} = Nested.validate([%{name: "a"}], %{})
    end

    test "validate accepts nil" do
      assert {:ok, nil} = Nested.validate(nil, %{})
    end

    test "parse_params returns value unchanged" do
      value = %{"name" => "test"}
      assert Nested.parse_params(value, %{}) == value
    end

    test "sanitize returns value unchanged" do
      value = %{"name" => "test"}
      assert Nested.sanitize(value, %{}) == value
    end

    test "default_ui returns nested type" do
      assert %{type: :nested} = Nested.default_ui()
    end
  end

  describe "type registry" do
    test "nested resolves to Nested module" do
      assert MishkaGervaz.Form.Types.Field.get_or_passthrough(:nested) == Nested
    end

    test "nested is a builtin type" do
      assert MishkaGervaz.Form.Types.Field.builtin?(:nested)
    end
  end

  describe "auto-detection: array embedded" do
    test "items field is detected as :nested" do
      field = FormInfo.field(NestedForm, :items)
      assert field.type == :nested
    end

    test "items field has type_module set" do
      field = FormInfo.field(NestedForm, :items)
      assert field.type_module == Nested
    end

    test "items field has rich sub-fields with name, type, label, required" do
      field = FormInfo.field(NestedForm, :items)

      assert is_list(field.nested_fields)
      assert length(field.nested_fields) > 0

      Enum.each(field.nested_fields, fn sub ->
        assert is_map(sub)
        assert Map.has_key?(sub, :name)
        assert Map.has_key?(sub, :type)
        assert Map.has_key?(sub, :label)
        assert Map.has_key?(sub, :required)
      end)
    end

    test "items field infers name sub-field as text and required" do
      field = FormInfo.field(NestedForm, :items)
      name_sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert name_sub != nil
      assert name_sub.type == :text
      assert name_sub.label == "Name"
      assert name_sub.required == true
    end

    test "items field infers count sub-field as number" do
      field = FormInfo.field(NestedForm, :items)
      count_sub = Enum.find(field.nested_fields, &(&1.name == :count))
      assert count_sub != nil
      assert count_sub.type == :number
    end

    test "items field infers active sub-field as checkbox" do
      field = FormInfo.field(NestedForm, :items)
      active_sub = Enum.find(field.nested_fields, &(&1.name == :active))
      assert active_sub != nil
      assert active_sub.type == :checkbox
    end

    test "items field has nested_mode :array in ui.extra" do
      field = FormInfo.field(NestedForm, :items)
      assert field.ui != nil
      assert field.ui.extra.nested_mode == :array
    end

    test "items field has add_label" do
      field = FormInfo.field(NestedForm, :items)
      assert field.add_label == "+ Add Item"
    end

    test "items field has remove_label" do
      field = FormInfo.field(NestedForm, :items)
      assert field.remove_label == "Remove"
    end
  end

  describe "auto-detection: single embedded" do
    test "address field is detected as :nested" do
      field = FormInfo.field(NestedForm, :address)
      assert field.type == :nested
    end

    test "address field has rich sub-fields" do
      field = FormInfo.field(NestedForm, :address)

      assert is_list(field.nested_fields)
      assert length(field.nested_fields) == 3

      names = Enum.map(field.nested_fields, & &1.name)
      assert :street in names
      assert :city in names
      assert :zip in names
    end

    test "address field infers street as required" do
      field = FormInfo.field(NestedForm, :address)
      street_sub = Enum.find(field.nested_fields, &(&1.name == :street))
      assert street_sub.required == true
    end

    test "address field infers zip as not required" do
      field = FormInfo.field(NestedForm, :address)
      zip_sub = Enum.find(field.nested_fields, &(&1.name == :zip))
      assert zip_sub.required == false
    end

    test "address field has nested_mode :single in ui.extra" do
      field = FormInfo.field(NestedForm, :address)
      assert field.ui != nil
      assert field.ui.extra.nested_mode == :single
    end
  end

  describe "explicit nested_fields preserved" do
    test "tags field uses manual sub-field maps" do
      field = FormInfo.field(NestedForm, :tags)
      assert field.type == :nested

      assert length(field.nested_fields) == 2

      name_sub = Enum.find(field.nested_fields, &(&1[:name] == :name))
      assert name_sub.label == "Tag Name"
      assert name_sub.type == :text

      value_sub = Enum.find(field.nested_fields, &(&1[:name] == :value))
      assert value_sub.label == "Tag Value"
      assert value_sub.type == :textarea
    end

    test "tags field has add_label" do
      field = FormInfo.field(NestedForm, :tags)
      assert field.add_label == "+ Add Tag"
    end
  end

  describe "non-embedded type not detected as nested" do
    test "title field stays as :text" do
      field = FormInfo.field(NestedForm, :title)
      assert field.type == :text
    end
  end

  describe "group resolution" do
    test "nested fields appear in groups" do
      groups = FormInfo.groups(NestedForm)
      main_group = Enum.find(groups, &(&1.name == :main))
      assert main_group != nil

      assert :items in main_group.fields
      assert :address in main_group.fields
      assert :tags in main_group.fields
    end
  end
end
