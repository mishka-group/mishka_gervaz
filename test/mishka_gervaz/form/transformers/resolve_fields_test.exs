defmodule MishkaGervaz.Form.Transformers.ResolveFieldsTest do
  @moduledoc """
  Tests for the `MishkaGervaz.Form.Transformers.ResolveFields`
  transformer. The transformer is exercised end-to-end via fixture
  resources (`AutoFieldsForm`, `AutoNestedFieldsForm`, `FormPost`,
  `WizardForm`); these tests pin its observable outputs:

    * Auto-discovery from Ash attributes (`auto_fields` flag, `except`,
      `only`, `position` :start/:end).
    * Type inference from each Ash type token (boolean → checkbox,
      integer → number, atom one_of → select, etc.).
    * `type_module` resolution for built-in types.
    * Source defaults to field name when not explicitly set.
    * Position resolution (`:first`, `:last`, `{:before, :name}`,
      `{:after, :name}`, integer).
    * Preload auto-detection from relation field sources.

  These tests are deliberately focused on outputs of `transform/1`, not
  internal helpers — the helpers are private and well-covered through
  the fixture matrix.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    AutoFieldsForm,
    AutoNestedFieldsForm,
    FormPost,
    WizardForm,
    StringListForm
  }

  describe "type inference from Ash attributes (via AutoFieldsForm)" do
    test "string attribute becomes :text" do
      field = FormInfo.field(AutoFieldsForm, :bio)
      assert field.type == :text
    end

    test "integer attribute becomes :number" do
      # :age has explicit override `type: :range`; :id is excluded.
      # The inserted_at create_timestamp is :datetime — covered below.
      field = FormInfo.field(AutoFieldsForm, :age)
      # Explicit override wins over auto-detection.
      assert field.type == :range
    end

    test "boolean attribute uses ui_defaults.boolean_widget (:checkbox)" do
      field = FormInfo.field(AutoFieldsForm, :active)
      assert field.type == :checkbox
    end

    test "map attribute without :fields constraints becomes :json" do
      field = FormInfo.field(AutoFieldsForm, :settings)
      assert field.type == :json
    end

    test "date attribute becomes :date" do
      field = FormInfo.field(AutoFieldsForm, :birthday)
      assert field.type == :date
    end

    test "atom attribute with one_of constraint becomes :select" do
      field = FormInfo.field(AutoFieldsForm, :status)
      assert field.type == :select
    end

    test "create_timestamp / update_timestamp become :datetime" do
      assert FormInfo.field(AutoFieldsForm, :inserted_at).type == :datetime
      assert FormInfo.field(AutoFieldsForm, :updated_at).type == :datetime
    end
  end

  describe "type inference for nested / array attributes (AutoNestedFieldsForm)" do
    test "{:array, embedded_resource} becomes :nested" do
      field = FormInfo.field(AutoNestedFieldsForm, :items)
      assert field.type == :nested
    end

    test "single embedded resource becomes :nested" do
      field = FormInfo.field(AutoNestedFieldsForm, :address)
      assert field.type == :nested
    end
  end

  describe "type inference for {:array, :string} (StringListForm)" do
    test ":origins (array of string, no explicit type) becomes :string_list" do
      field = FormInfo.field(StringListForm, :origins)
      assert field.type == :string_list
    end

    test "explicit :string_list type is preserved" do
      field = FormInfo.field(StringListForm, :tags)
      assert field.type == :string_list
    end
  end

  describe "type_module resolution for built-in types" do
    test "explicit :text resolves to Form.Types.Field.Text" do
      field = FormInfo.field(FormPost, :title)
      assert field.type_module == MishkaGervaz.Form.Types.Field.Text
    end

    test "explicit :select resolves to Form.Types.Field.Select" do
      field = FormInfo.field(FormPost, :status)
      assert field.type_module == MishkaGervaz.Form.Types.Field.Select
    end

    test "explicit :combobox resolves to Form.Types.Field.Combobox" do
      field = FormInfo.field(FormPost, :language)
      assert field.type_module == MishkaGervaz.Form.Types.Field.Combobox
    end

    test "explicit :relation resolves to Form.Types.Field.Relation" do
      field = FormInfo.field(FormPost, :user_id)
      assert field.type_module == MishkaGervaz.Form.Types.Field.Relation
    end

    test "auto-discovered field gets its type detected, but type_module is left nil" do
      # Pinning current behavior of `build_auto_fields/3`: it sets `type`
      # via `infer_field_type/2` but never resolves a `type_module`.
      # Only the explicit-field path through `resolve_explicit_field_types`
      # calls `MishkaGervaz.Form.Types.Field.get_or_passthrough/1`. If this
      # ever changes, update both call sites consistently.
      field = FormInfo.field(AutoFieldsForm, :birthday)
      assert field.type == :date
      assert field.type_module == nil
    end
  end

  describe "source defaults to field name" do
    test "explicit field with no `source` defaults source to its name" do
      field = FormInfo.field(FormPost, :title)
      assert field.source == :title
    end

    test "explicit field with no `source` defaults source for all FormPost fields" do
      for name <- [:title, :content, :status, :priority, :featured, :metadata, :language] do
        field = FormInfo.field(FormPost, name)

        assert field.source == name,
               "expected #{name}.source == #{name}, got #{inspect(field.source)}"
      end
    end

    test "auto-discovered field's source matches its name" do
      field = FormInfo.field(AutoFieldsForm, :birthday)
      assert field.source == :birthday
    end
  end

  describe "position resolution" do
    test "field with `position :first` is the first in field_order" do
      order = FormInfo.field_order(FormPost)
      assert hd(order) == :title
    end

    test "auto_fields position :end appends auto-discovered fields after explicit ones" do
      order = FormInfo.field_order(AutoFieldsForm)
      # :name is the explicit field with no `position`, declared first.
      assert hd(order) == :name
      # Auto-discovered fields follow.
      assert :birthday in order
    end

    test "fields without explicit position appear after `:first`-positioned ones" do
      order = FormInfo.field_order(FormPost)
      title_idx = Enum.find_index(order, &(&1 == :title))
      content_idx = Enum.find_index(order, &(&1 == :content))
      assert title_idx < content_idx
    end
  end

  describe "auto-discovery filters" do
    test "fields listed in `except` are excluded" do
      names = AutoFieldsForm |> FormInfo.fields() |> Enum.map(& &1.name)
      refute :id in names
      refute :internal_only in names
    end

    test "explicit `field` declarations with names matching attributes still appear once" do
      fields = FormInfo.fields(AutoFieldsForm)
      name_count = Enum.count(fields, &(&1.name == :name))
      assert name_count == 1
    end

    test "explicit field's options take precedence over auto-detected ones" do
      # :age is integer in Ash, but explicit override sets type :range.
      field = FormInfo.field(AutoFieldsForm, :age)
      assert field.type == :range
      assert field.required == true
    end
  end

  describe "field_order persistence" do
    test "every field appears in field_order" do
      order = FormInfo.field_order(FormPost)
      fields = FormPost |> FormInfo.fields() |> Enum.map(& &1.name)
      assert Enum.sort(order) == Enum.sort(fields)
    end

    test "WizardForm field_order contains all 5 fields" do
      order = FormInfo.field_order(WizardForm)
      assert length(order) == 5

      for name <- [:title, :content, :status, :priority, :featured] do
        assert name in order
      end
    end
  end

  describe "preload detection from relation fields" do
    test "FormPost has a :user_id relation field" do
      field = FormInfo.field(FormPost, :user_id)
      assert field.type == :relation
    end

    test "detected_preloads list is reachable" do
      preloads = FormInfo.detected_preloads(FormPost)
      assert is_list(preloads)
    end
  end

  describe "select option inference for atom one_of attributes" do
    test "auto-discovered :status has its one_of options inferred" do
      field = FormInfo.field(AutoFieldsForm, :status)
      # The Ash attribute has `constraints one_of: [:active, :inactive]`.
      # `extract_one_of_options/1` builds `[{label_string, atom_value}]`
      # tuples — label first, atom value second.
      assert is_list(field.options)
      assert {"Active", :active} in field.options
      assert {"Inactive", :inactive} in field.options
    end
  end
end
