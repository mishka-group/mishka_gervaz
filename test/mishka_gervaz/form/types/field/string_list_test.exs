defmodule MishkaGervaz.Form.Types.Field.StringListTest do
  @moduledoc """
  Tests for the string_list field type, type registry, and auto-type detection.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.StringList
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.StringListForm

  describe "type module behaviour" do
    test "render returns assigns unchanged" do
      assigns = %{some: :data}
      assert StringList.render(assigns, %{}) == assigns
    end

    test "validate accepts a list" do
      assert {:ok, ["a", "b"]} = StringList.validate(["a", "b"], %{})
    end

    test "validate wraps a binary in a list" do
      assert {:ok, ["hello"]} = StringList.validate("hello", %{})
    end

    test "validate returns empty list for nil" do
      assert {:ok, []} = StringList.validate(nil, %{})
    end

    test "validate returns empty list for empty string" do
      assert {:ok, []} = StringList.validate("", %{})
    end

    test "parse_params filters empty strings from list" do
      assert ["a", "b"] = StringList.parse_params(["a", "", "b", ""], %{})
    end

    test "parse_params wraps non-empty binary" do
      assert ["hello"] = StringList.parse_params("hello", %{})
    end

    test "parse_params returns empty list for nil" do
      assert [] = StringList.parse_params(nil, %{})
    end

    test "parse_params returns empty list for empty string" do
      assert [] = StringList.parse_params("", %{})
    end

    test "default_ui returns string_list type" do
      assert %{type: :string_list} = StringList.default_ui()
    end
  end

  describe "type registry" do
    test "string_list resolves to StringList module" do
      assert MishkaGervaz.Form.Types.Field.get_or_passthrough(:string_list) == StringList
    end

    test "string_list is a builtin type" do
      assert MishkaGervaz.Form.Types.Field.builtin?(:string_list)
    end
  end

  describe "DSL compilation with explicit :string_list" do
    test "tags field has type :string_list" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.type == :string_list
    end

    test "tags field has type_module set" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.type_module == StringList
    end

    test "tags field has add_label" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.add_label == "+ Add Tag"
    end

    test "tags field has remove_label" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.remove_label == "Remove"
    end

    test "tags field has UI label" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.ui.label == "Tags"
    end

    test "tags field has UI placeholder" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.ui.placeholder == "Enter a tag"
    end
  end

  describe "auto-type detection" do
    test "origins field (no explicit type) is detected as :string_list" do
      field = FormInfo.field(StringListForm, :origins)
      assert field.type == :string_list
    end

    test "origins field has type_module set via detection" do
      field = FormInfo.field(StringListForm, :origins)
      assert field.type_module == StringList
    end

    test "origins field has function add_label" do
      field = FormInfo.field(StringListForm, :origins)
      assert is_function(field.add_label, 0)
      assert field.add_label.() == "Add Origin"
    end

    test "title field with explicit :text is NOT overridden" do
      field = FormInfo.field(StringListForm, :title)
      assert field.type == :text
    end
  end

  describe "group resolution" do
    test "string_list fields appear in groups" do
      groups = FormInfo.groups(StringListForm)
      main_group = Enum.find(groups, &(&1.name == :main))
      assert main_group != nil

      assert :tags in main_group.fields
      assert :origins in main_group.fields
    end
  end
end
