defmodule MishkaGervaz.Form.Types.Field.AutoNestedFieldsTest do
  @moduledoc """
  Tests for auto_fields option on :nested fields.

  When auto_fields is true, explicit nested_field entries override matching
  inferred fields while non-mentioned inferred fields are kept.
  When false (default), only explicit nested_field entries are included.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoNestedFieldsForm

  # ---------------------------------------------------------------------------
  # auto_fields true — array embed (items)
  # ---------------------------------------------------------------------------
  describe "auto_fields true: array embed (items)" do
    test "items field is :nested with sub-fields" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      assert field.type == :nested
      assert is_list(field.nested_fields)
    end

    test "overridden :name has custom label and placeholder" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub != nil
      assert sub.label == "Custom Item Name"
      assert sub.placeholder == "Enter name..."
    end

    test "non-mentioned :value is kept from auto-detection" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :value))
      assert sub != nil
      assert sub.type == :text
    end

    test "non-mentioned :count is kept from auto-detection" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :count))
      assert sub != nil
      assert sub.type == :number
    end

    test "non-mentioned :active is kept from auto-detection" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :active))
      assert sub != nil
      assert sub.type == :checkbox
    end

    test "total count is 4 (1 overridden + 3 auto-detected)" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      assert length(field.nested_fields) == 4
    end

    test "overridden :name retains auto-detected type and required" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub.type == :text
      assert sub.required == true
    end

    test "nested_mode is :array" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      assert field.ui.extra.nested_mode == :array
    end
  end

  # ---------------------------------------------------------------------------
  # auto_fields true — single embed (address)
  # ---------------------------------------------------------------------------
  describe "auto_fields true: single embed (address)" do
    test "address field is :nested with sub-fields" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      assert field.type == :nested
      assert is_list(field.nested_fields)
    end

    test "overridden :street has custom type, label, placeholder, rows, and span" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      sub = Enum.find(field.nested_fields, &(&1.name == :street))
      assert sub != nil
      assert sub.type == :textarea
      assert sub.label == "Full Street Address"
      assert sub.placeholder == "123 Main St, Apt 4"
      assert sub.rows == 3
      assert sub.span == 2
    end

    test "non-mentioned :city is kept from auto-detection" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      sub = Enum.find(field.nested_fields, &(&1.name == :city))
      assert sub != nil
      assert sub.type == :text
      assert sub.required == true
    end

    test "non-mentioned :zip is kept from auto-detection" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      sub = Enum.find(field.nested_fields, &(&1.name == :zip))
      assert sub != nil
      assert sub.type == :text
      assert sub.required == false
    end

    test "total count is 3 (1 overridden + 2 auto-detected)" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      assert length(field.nested_fields) == 3
    end

    test "nested_mode is :single" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      assert field.ui.extra.nested_mode == :single
    end
  end

  # ---------------------------------------------------------------------------
  # auto_fields false (default) — only explicit fields kept (notes)
  # ---------------------------------------------------------------------------
  describe "auto_fields false (default): notes" do
    test "notes only contains the explicitly declared :name" do
      field = FormInfo.field(AutoNestedFieldsForm, :notes)
      assert length(field.nested_fields) == 1
      assert hd(field.nested_fields).name == :name
    end

    test "non-mentioned :value is excluded" do
      field = FormInfo.field(AutoNestedFieldsForm, :notes)
      sub = Enum.find(field.nested_fields, &(&1.name == :value))
      assert sub == nil
    end

    test "non-mentioned :count is excluded" do
      field = FormInfo.field(AutoNestedFieldsForm, :notes)
      sub = Enum.find(field.nested_fields, &(&1.name == :count))
      assert sub == nil
    end

    test "non-mentioned :active is excluded" do
      field = FormInfo.field(AutoNestedFieldsForm, :notes)
      sub = Enum.find(field.nested_fields, &(&1.name == :active))
      assert sub == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Ordering: overrides stay in original inferred position (in-place replace)
  # ---------------------------------------------------------------------------
  describe "ordering: in-place replacement" do
    test "items: overridden :name stays in its original position (first)" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      names = Enum.map(field.nested_fields, & &1.name)

      # TestEmbed attributes: name, value, count, active (public order)
      assert hd(names) == :name
    end

    test "items: auto-detected fields keep their original order" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      names = Enum.map(field.nested_fields, & &1.name)
      name_idx = Enum.find_index(names, &(&1 == :name))
      value_idx = Enum.find_index(names, &(&1 == :value))
      count_idx = Enum.find_index(names, &(&1 == :count))
      active_idx = Enum.find_index(names, &(&1 == :active))

      assert name_idx < value_idx
      assert value_idx < count_idx
      assert count_idx < active_idx
    end

    test "address: overridden :street stays in its original position (first)" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      names = Enum.map(field.nested_fields, & &1.name)

      # SingleEmbed attributes: street, city, zip
      assert hd(names) == :street
    end
  end

  # ---------------------------------------------------------------------------
  # Position option: reorder nested sub-fields
  # ---------------------------------------------------------------------------
  describe "position option" do
    test "position :last moves field to end" do
      field = FormInfo.field(AutoNestedFieldsForm, :positioned_items)
      names = Enum.map(field.nested_fields, & &1.name)

      assert List.last(names) == :name
    end

    test "position :first moves field to beginning" do
      field = FormInfo.field(AutoNestedFieldsForm, :positioned_items)
      names = Enum.map(field.nested_fields, & &1.name)

      assert hd(names) == :active
    end

    test "positioned_items has all 4 fields" do
      field = FormInfo.field(AutoNestedFieldsForm, :positioned_items)
      assert length(field.nested_fields) == 4
    end

    test "fields without position keep relative order between positioned ones" do
      field = FormInfo.field(AutoNestedFieldsForm, :positioned_items)
      names = Enum.map(field.nested_fields, & &1.name)

      # :active is :first, :name is :last
      # :value and :count keep their relative order in the middle
      value_idx = Enum.find_index(names, &(&1 == :value))
      count_idx = Enum.find_index(names, &(&1 == :count))
      assert value_idx < count_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Position option: integer positions
  # ---------------------------------------------------------------------------
  describe "position option: integer" do
    test "integer position 0 moves :count to first" do
      field = FormInfo.field(AutoNestedFieldsForm, :integer_pos_items)
      names = Enum.map(field.nested_fields, & &1.name)

      assert hd(names) == :count
    end

    test "integer position 1 places :active second" do
      field = FormInfo.field(AutoNestedFieldsForm, :integer_pos_items)
      names = Enum.map(field.nested_fields, & &1.name)

      assert Enum.at(names, 1) == :active
    end

    test "non-positioned fields fill remaining slots" do
      field = FormInfo.field(AutoNestedFieldsForm, :integer_pos_items)
      names = Enum.map(field.nested_fields, & &1.name)

      assert length(names) == 4
      assert :name in names
      assert :value in names
    end

    test "integer positioned fields appear before non-positioned with same key" do
      field = FormInfo.field(AutoNestedFieldsForm, :integer_pos_items)
      names = Enum.map(field.nested_fields, & &1.name)

      count_idx = Enum.find_index(names, &(&1 == :count))
      active_idx = Enum.find_index(names, &(&1 == :active))
      assert count_idx < active_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Position option: {:before, :field} and {:after, :field}
  # ---------------------------------------------------------------------------
  describe "position option: relative (before/after)" do
    test "{:before, :value} places :active just before :value" do
      field = FormInfo.field(AutoNestedFieldsForm, :relative_pos_items)
      names = Enum.map(field.nested_fields, & &1.name)

      active_idx = Enum.find_index(names, &(&1 == :active))
      value_idx = Enum.find_index(names, &(&1 == :value))
      assert active_idx == value_idx - 1
    end

    test "{:after, :name} places :count just after :name" do
      field = FormInfo.field(AutoNestedFieldsForm, :relative_pos_items)
      names = Enum.map(field.nested_fields, & &1.name)

      name_idx = Enum.find_index(names, &(&1 == :name))
      count_idx = Enum.find_index(names, &(&1 == :count))
      assert count_idx == name_idx + 1
    end

    test "relative_pos_items has all 4 fields" do
      field = FormInfo.field(AutoNestedFieldsForm, :relative_pos_items)
      assert length(field.nested_fields) == 4
    end

    test "position value is stored in resolved sub-field" do
      field = FormInfo.field(AutoNestedFieldsForm, :relative_pos_items)
      active = Enum.find(field.nested_fields, &(&1.name == :active))
      count = Enum.find(field.nested_fields, &(&1.name == :count))

      assert active.position == {:before, :value}
      assert count.position == {:after, :name}
    end
  end

  # ---------------------------------------------------------------------------
  # Overridden sub-field properties preservation
  # ---------------------------------------------------------------------------
  describe "override properties preserved with auto_fields" do
    test "overridden visible defaults to true" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub.visible == true
    end

    test "overridden readonly defaults to false" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :name))
      assert sub.readonly == false
    end

    test "auto-detected fields have no position" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      sub = Enum.find(field.nested_fields, &(&1.name == :value))
      assert Map.get(sub, :position) == nil
    end

    test "nested_source is :embedded for embed-based fields" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      assert field.ui.extra.nested_source == :embedded
    end
  end

  # ---------------------------------------------------------------------------
  # Runtime config
  # ---------------------------------------------------------------------------
  describe "runtime config" do
    test "items field in runtime config has all 4 sub-fields" do
      config = FormInfo.config(AutoNestedFieldsForm)
      items_field = Enum.find(config.fields.list, &(&1.name == :items))
      assert items_field != nil
      assert length(items_field.nested_fields) == 4
    end

    test "notes field in runtime config has only 1 sub-field" do
      config = FormInfo.config(AutoNestedFieldsForm)
      notes_field = Enum.find(config.fields.list, &(&1.name == :notes))
      assert notes_field != nil
      assert length(notes_field.nested_fields) == 1
    end

    test "positioned_items field in runtime config preserves position order" do
      config = FormInfo.config(AutoNestedFieldsForm)
      field = Enum.find(config.fields.list, &(&1.name == :positioned_items))
      names = Enum.map(field.nested_fields, & &1.name)

      assert hd(names) == :active
      assert List.last(names) == :name
    end

    test "integer_pos_items field in runtime config has all 4 sub-fields" do
      config = FormInfo.config(AutoNestedFieldsForm)
      field = Enum.find(config.fields.list, &(&1.name == :integer_pos_items))
      assert field != nil
      assert length(field.nested_fields) == 4
    end

    test "relative_pos_items field in runtime config has all 4 sub-fields" do
      config = FormInfo.config(AutoNestedFieldsForm)
      field = Enum.find(config.fields.list, &(&1.name == :relative_pos_items))
      assert field != nil
      assert length(field.nested_fields) == 4
    end
  end
end
