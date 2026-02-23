defmodule MishkaGervaz.Form.Types.Field.NestedTest do
  @moduledoc """
  Comprehensive tests for nested field type: type module, embedded resource auto-detection,
  nested_field DSL entity, merge logic, and backward compatibility.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Nested
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.NestedForm
  alias MishkaGervaz.Test.Resources.NestedDslForm

  # ---------------------------------------------------------------------------
  # Type module behaviour
  # ---------------------------------------------------------------------------
  describe "type module behaviour" do
    test "render returns assigns unchanged" do
      assigns = %{some: :data}
      assert Nested.render(assigns, %{}) == assigns
    end

    test "validate accepts a map" do
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

  # ---------------------------------------------------------------------------
  # Type registry
  # ---------------------------------------------------------------------------
  describe "type registry" do
    test "nested resolves to Nested module" do
      assert MishkaGervaz.Form.Types.Field.get_or_passthrough(:nested) == Nested
    end

    test "nested is a builtin type" do
      assert MishkaGervaz.Form.Types.Field.builtin?(:nested)
    end
  end

  # ---------------------------------------------------------------------------
  # NestedForm: auto-detection — array embedded (TestEmbed)
  # ---------------------------------------------------------------------------
  describe "NestedForm: array embedded auto-detection (items)" do
    test "items field is detected as :nested" do
      field = FormInfo.field(NestedForm, :items)
      assert field.type == :nested
    end

    test "items field has type_module set" do
      field = FormInfo.field(NestedForm, :items)
      assert field.type_module == Nested
    end

    test "items field has 4 rich sub-fields from TestEmbed" do
      field = FormInfo.field(NestedForm, :items)
      assert is_list(field.nested_fields)
      assert length(field.nested_fields) == 4

      names = Enum.map(field.nested_fields, & &1.name)
      assert :name in names
      assert :value in names
      assert :count in names
      assert :active in names
    end

    test "each auto-inferred sub-field has name, type, label, required, placeholder" do
      field = FormInfo.field(NestedForm, :items)

      Enum.each(field.nested_fields, fn sub ->
        assert is_map(sub)
        assert Map.has_key?(sub, :name)
        assert Map.has_key?(sub, :type)
        assert Map.has_key?(sub, :label)
        assert Map.has_key?(sub, :required)
        assert Map.has_key?(sub, :placeholder)
      end)
    end

    test "name sub-field inferred as text and required" do
      field = FormInfo.field(NestedForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub.type == :text
      assert sub.label == "Name"
      assert sub.required == true
    end

    test "count sub-field inferred as number" do
      field = FormInfo.field(NestedForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :count))
      assert sub.type == :number
    end

    test "active sub-field inferred as checkbox" do
      field = FormInfo.field(NestedForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :active))
      assert sub.type == :checkbox
    end

    test "value sub-field inferred as text and not required" do
      field = FormInfo.field(NestedForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :value))
      assert sub.type == :text
      assert sub.required == false
    end

    test "nested_mode is :array" do
      field = FormInfo.field(NestedForm, :items)
      assert field.ui != nil
      assert field.ui.extra.nested_mode == :array
    end

    test "add_label from ui do block" do
      field = FormInfo.field(NestedForm, :items)
      assert field.add_label == "+ Add Item"
    end

    test "remove_label from ui do block" do
      field = FormInfo.field(NestedForm, :items)
      assert field.remove_label == "Remove"
    end
  end

  # ---------------------------------------------------------------------------
  # NestedForm: auto-detection — single embedded (SingleEmbed)
  # ---------------------------------------------------------------------------
  describe "NestedForm: single embedded auto-detection (address)" do
    test "address field is detected as :nested" do
      field = FormInfo.field(NestedForm, :address)
      assert field.type == :nested
    end

    test "address field has 3 sub-fields from SingleEmbed" do
      field = FormInfo.field(NestedForm, :address)
      assert length(field.nested_fields) == 3

      names = Enum.map(field.nested_fields, & &1.name)
      assert :street in names
      assert :city in names
      assert :zip in names
    end

    test "street is required, zip is not" do
      field = FormInfo.field(NestedForm, :address)
      street = Enum.find(field.nested_fields, &(&1.name == :street))
      zip = Enum.find(field.nested_fields, &(&1.name == :zip))
      assert street.required == true
      assert zip.required == false
    end

    test "nested_mode is :single" do
      field = FormInfo.field(NestedForm, :address)
      assert field.ui.extra.nested_mode == :single
    end

    test "all sub-fields are text type (all strings)" do
      field = FormInfo.field(NestedForm, :address)

      Enum.each(field.nested_fields, fn sub ->
        assert sub.type == :text
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # NestedForm: explicit map-based nested_fields (backward compat)
  # ---------------------------------------------------------------------------
  describe "NestedForm: map-based nested_fields (tags)" do
    test "tags field uses manual sub-field maps" do
      field = FormInfo.field(NestedForm, :tags)
      assert field.type == :nested
      assert length(field.nested_fields) == 2
    end

    test "manual maps have correct labels and types" do
      field = FormInfo.field(NestedForm, :tags)

      name_sub = Enum.find(field.nested_fields, &(&1[:name] == :name))
      assert name_sub.label == "Tag Name"
      assert name_sub.type == :text

      value_sub = Enum.find(field.nested_fields, &(&1[:name] == :value))
      assert value_sub.label == "Tag Value"
      assert value_sub.type == :textarea
    end

    test "tags has add_label from field-level option" do
      field = FormInfo.field(NestedForm, :tags)
      assert field.add_label == "+ Add Tag"
    end
  end

  # ---------------------------------------------------------------------------
  # NestedForm: non-embedded type stays non-nested
  # ---------------------------------------------------------------------------
  describe "NestedForm: non-nested fields" do
    test "title field is :text, not :nested" do
      field = FormInfo.field(NestedForm, :title)
      assert field.type == :text
    end
  end

  # ---------------------------------------------------------------------------
  # NestedForm: group resolution
  # ---------------------------------------------------------------------------
  describe "NestedForm: group resolution" do
    test "nested fields appear in the :main group" do
      groups = FormInfo.groups(NestedForm)
      main = Enum.find(groups, &(&1.name == :main))
      assert main != nil
      assert :items in main.fields
      assert :address in main.fields
      assert :tags in main.fields
    end
  end

  # ---------------------------------------------------------------------------
  # NestedDslForm: nested_field DSL entity — overrides with ui blocks
  # ---------------------------------------------------------------------------
  describe "NestedDslForm: nested_field entity overrides (items)" do
    test "items field is :nested with sub-fields" do
      field = FormInfo.field(NestedDslForm, :items)
      assert field.type == :nested
      assert is_list(field.nested_fields)
      assert length(field.nested_fields) > 0
    end

    test "explicit nested_field :name has custom label and placeholder" do
      field = FormInfo.field(NestedDslForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub != nil
      assert sub.label == "Item Name"
      assert sub.placeholder == "e.g. Widget"
    end

    test "explicit nested_field :count has custom label, required override, and retains number type" do
      field = FormInfo.field(NestedDslForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :count))
      assert sub != nil
      assert sub.label == "Quantity"
      assert sub.placeholder == "0"
      assert sub.required == true
      assert sub.type == :number
    end

    test "explicit nested_field :active is hidden (visible: false)" do
      field = FormInfo.field(NestedDslForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :active))
      assert sub != nil
      assert sub.visible == false
    end

    test "auto-inferred :value sub-field is excluded when explicit nested_fields exist" do
      field = FormInfo.field(NestedDslForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :value))
      assert sub == nil
    end

    test "items field has nested_mode :array" do
      field = FormInfo.field(NestedDslForm, :items)
      assert field.ui.extra.nested_mode == :array
    end

    test "items add_label comes from ui do block" do
      field = FormInfo.field(NestedDslForm, :items)
      assert field.add_label == "+ Add Custom Item"
    end

    test "items remove_label comes from ui do block" do
      field = FormInfo.field(NestedDslForm, :items)
      assert field.remove_label == "Remove Item"
    end
  end

  # ---------------------------------------------------------------------------
  # NestedDslForm: nested_field entity overrides on single embed (address)
  # ---------------------------------------------------------------------------
  describe "NestedDslForm: nested_field entity overrides (address)" do
    test "address is :nested with only explicit sub-fields" do
      field = FormInfo.field(NestedDslForm, :address)
      assert field.type == :nested
      assert length(field.nested_fields) == 2
    end

    test "street has custom label, placeholder, and span" do
      field = FormInfo.field(NestedDslForm, :address)
      sub = Enum.find(field.nested_fields, &(&1.name == :street))
      assert sub.label == "Street Address"
      assert sub.placeholder == "123 Main St"
      assert sub.span == 2
    end

    test "zip has custom placeholder, auto-detected label" do
      field = FormInfo.field(NestedDslForm, :address)
      sub = Enum.find(field.nested_fields, &(&1.name == :zip))
      assert sub.placeholder == "e.g. 90210"
    end

    test "city is excluded when explicit nested_fields exist" do
      field = FormInfo.field(NestedDslForm, :address)
      sub = Enum.find(field.nested_fields, &(&1.name == :city))
      assert sub == nil
    end

    test "address nested_mode is :single" do
      field = FormInfo.field(NestedDslForm, :address)
      assert field.ui.extra.nested_mode == :single
    end
  end

  # ---------------------------------------------------------------------------
  # NestedDslForm: nested_field with type override (notes — text -> textarea)
  # ---------------------------------------------------------------------------
  describe "NestedDslForm: type override (notes)" do
    test "notes is :nested" do
      field = FormInfo.field(NestedDslForm, :notes)
      assert field.type == :nested
    end

    test "notes :name override to :text with custom label" do
      field = FormInfo.field(NestedDslForm, :notes)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub.type == :text
      assert sub.label == "Note Title"
      assert sub.placeholder == "Title..."
      assert sub.required == true
    end

    test "notes :value override to :textarea with rows and class" do
      field = FormInfo.field(NestedDslForm, :notes)
      sub = Enum.find(field.nested_fields, &(&1.name == :value))
      assert sub.type == :textarea
      assert sub.label == "Note Content"
      assert sub.placeholder == "Write your note..."
      assert sub.rows == 6
      assert sub.class == "font-mono text-sm"
    end

    test "notes only contains explicitly declared sub-fields" do
      field = FormInfo.field(NestedDslForm, :notes)
      names = Enum.map(field.nested_fields, & &1.name)
      assert :name in names
      assert :value in names
      refute :count in names
      refute :active in names
    end

    test "notes has add_label from ui do block" do
      field = FormInfo.field(NestedDslForm, :notes)
      assert field.add_label == "+ Add Note"
    end

    test "notes nested_mode is :array" do
      field = FormInfo.field(NestedDslForm, :notes)
      assert field.ui.extra.nested_mode == :array
    end
  end

  # ---------------------------------------------------------------------------
  # NestedDslForm: group resolution
  # ---------------------------------------------------------------------------
  describe "NestedDslForm: group resolution" do
    test "all nested fields in :main group" do
      groups = FormInfo.groups(NestedDslForm)
      main = Enum.find(groups, &(&1.name == :main))
      assert :items in main.fields
      assert :address in main.fields
      assert :notes in main.fields
    end
  end

  # ---------------------------------------------------------------------------
  # Merge logic: explicit overrides appear first, auto-inferred remainder last
  # ---------------------------------------------------------------------------
  describe "merge ordering" do
    test "explicit nested_fields appear before auto-inferred in items" do
      field = FormInfo.field(NestedDslForm, :items)
      names = Enum.map(field.nested_fields, & &1.name)
      name_idx = Enum.find_index(names, &(&1 == :name))
      count_idx = Enum.find_index(names, &(&1 == :count))
      active_idx = Enum.find_index(names, &(&1 == :active))
      value_idx = Enum.find_index(names, &(&1 == :value))

      assert name_idx < value_idx
      assert count_idx < value_idx
      assert active_idx < value_idx
    end

    test "explicit nested_fields appear before auto-inferred in address" do
      field = FormInfo.field(NestedDslForm, :address)
      names = Enum.map(field.nested_fields, & &1.name)
      street_idx = Enum.find_index(names, &(&1 == :street))
      zip_idx = Enum.find_index(names, &(&1 == :zip))
      city_idx = Enum.find_index(names, &(&1 == :city))

      assert street_idx < city_idx
      assert zip_idx < city_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Sub-field placeholder defaults
  # ---------------------------------------------------------------------------
  describe "placeholder defaults" do
    test "auto-inferred sub-fields get label as placeholder" do
      field = FormInfo.field(NestedForm, :items)

      Enum.each(field.nested_fields, fn sub ->
        assert sub.placeholder == sub.label
      end)
    end

    test "explicit nested_field without placeholder falls back to label" do
      field = FormInfo.field(NestedDslForm, :address)
      zip = Enum.find(field.nested_fields, &(&1.name == :zip))
      assert zip.placeholder == "e.g. 90210"
    end

    test "explicit nested_field with placeholder uses that" do
      field = FormInfo.field(NestedDslForm, :address)
      street = Enum.find(field.nested_fields, &(&1.name == :street))
      assert street.placeholder == "123 Main St"
    end
  end

  # ---------------------------------------------------------------------------
  # Field.Ui: add_label/remove_label promotion
  # ---------------------------------------------------------------------------
  describe "Field.Ui: label promotion" do
    test "ui add_label is promoted to field.add_label" do
      field = FormInfo.field(NestedForm, :items)
      assert field.add_label == "+ Add Item"
      assert field.ui.add_label == "+ Add Item"
    end

    test "ui remove_label is promoted to field.remove_label" do
      field = FormInfo.field(NestedForm, :items)
      assert field.remove_label == "Remove"
      assert field.ui.remove_label == "Remove"
    end

    test "field-level add_label still works (tags)" do
      field = FormInfo.field(NestedForm, :tags)
      assert field.add_label == "+ Add Tag"
    end
  end

  # ---------------------------------------------------------------------------
  # Runtime config includes nested field data
  # ---------------------------------------------------------------------------
  describe "runtime config" do
    test "NestedForm runtime config has items with nested_fields" do
      config = FormInfo.config(NestedForm)
      items_field = Enum.find(config.fields.list, &(&1.name == :items))
      assert items_field != nil
      assert is_list(items_field.nested_fields)
      assert length(items_field.nested_fields) > 0
    end

    test "NestedDslForm runtime config has notes with overridden nested_fields" do
      config = FormInfo.config(NestedDslForm)
      notes_field = Enum.find(config.fields.list, &(&1.name == :notes))
      assert notes_field != nil
      sub = Enum.find(notes_field.nested_fields, &(&1.name == :value))
      assert sub.type == :textarea
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------
  describe "edge cases" do
    test "auto-inferred sub-fields exclude :id, :inserted_at, :updated_at" do
      field = FormInfo.field(NestedForm, :items)
      names = Enum.map(field.nested_fields, & &1.name)
      refute :id in names
      refute :inserted_at in names
      refute :updated_at in names
    end

    test "single embed address has no add_label or remove_label" do
      field = FormInfo.field(NestedForm, :address)
      assert is_nil(field.add_label)
      assert is_nil(field.remove_label)
    end
  end
end
