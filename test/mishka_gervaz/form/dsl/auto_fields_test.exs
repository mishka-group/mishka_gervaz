defmodule MishkaGervaz.Form.DSL.AutoFieldsTest do
  @moduledoc """
  Tests for the form auto_fields DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoFieldsForm

  describe "auto-discovery" do
    test "fields are discovered from resource attributes" do
      fields = FormInfo.fields(AutoFieldsForm)
      names = Enum.map(fields, & &1.name)

      # Explicit field + auto-discovered (minus :id and :internal_only)
      assert :name in names
      assert :age in names
      assert :active in names
      assert :bio in names
      assert :settings in names
      assert :birthday in names
      assert :status in names
      assert :inserted_at in names
      assert :updated_at in names
    end

    test "explicit :name field is present and not duplicated" do
      fields = FormInfo.fields(AutoFieldsForm)
      name_fields = Enum.filter(fields, &(&1.name == :name))
      assert length(name_fields) == 1
    end

    test "explicit :name field retains its type" do
      field = FormInfo.field(AutoFieldsForm, :name)
      assert field.type == :text
      assert field.required == true
    end
  end

  describe "except filter" do
    test ":id is excluded" do
      fields = FormInfo.fields(AutoFieldsForm)
      names = Enum.map(fields, & &1.name)
      refute :id in names
    end

    test ":internal_only is excluded" do
      fields = FormInfo.fields(AutoFieldsForm)
      names = Enum.map(fields, & &1.name)
      refute :internal_only in names
    end
  end

  describe "only filter" do
    test "only specified attributes are discovered" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.OnlyFilter#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
          attribute :content, :string, public?: true
          attribute :extra, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :only_filter_#{unique_id}
              route "/admin/only-filter-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              auto_fields only: [:title, :content]
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(code)
      end)

      module = Module.concat(MishkaGervaz.Test, :"OnlyFilter#{unique_id}")
      fields = FormInfo.fields(module)
      names = Enum.map(fields, & &1.name)

      assert :title in names
      assert :content in names
      refute :extra in names
      refute :id in names
    end
  end

  describe "position" do
    test ":end places auto fields after explicit fields" do
      fields = FormInfo.fields(AutoFieldsForm)
      # :name is explicit and should be first (position :end = explicit ++ auto)
      assert hd(fields).name == :name
    end

    test ":start places auto fields before explicit fields" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StartPosition#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
          attribute :age, :integer, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :start_pos_#{unique_id}
              route "/admin/start-pos-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text

              auto_fields except: [:id], position: :start
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(code)
      end)

      module = Module.concat(MishkaGervaz.Test, :"StartPosition#{unique_id}")
      fields = FormInfo.fields(module)

      # Auto fields should come before explicit :title
      title_index = Enum.find_index(fields, &(&1.name == :title))
      age_index = Enum.find_index(fields, &(&1.name == :age))
      assert age_index < title_index
    end
  end

  describe "defaults" do
    test "required defaults applied to auto-discovered fields" do
      # defaults required: false in AutoFieldsForm
      field = FormInfo.field(AutoFieldsForm, :active)
      assert field.required == false
    end

    test "visible defaults applied to auto-discovered fields" do
      field = FormInfo.field(AutoFieldsForm, :active)
      assert field.visible == true
    end

    test "readonly defaults applied to auto-discovered fields" do
      field = FormInfo.field(AutoFieldsForm, :active)
      assert field.readonly == false
    end
  end

  describe "ui_defaults" do
    test "boolean fields get boolean_widget from ui_defaults" do
      field = FormInfo.field(AutoFieldsForm, :active)
      assert field.type == :checkbox
    end
  end

  describe "type inference" do
    test "boolean attribute becomes checkbox" do
      field = FormInfo.field(AutoFieldsForm, :active)
      assert field.type == :checkbox
    end

    test "integer attribute becomes number (overridden to range for :age)" do
      field = FormInfo.field(AutoFieldsForm, :age)
      assert field.type == :range
    end

    test "string attribute becomes text" do
      field = FormInfo.field(AutoFieldsForm, :bio)
      assert field.type == :text
    end

    test "map attribute becomes json" do
      field = FormInfo.field(AutoFieldsForm, :settings)
      assert field.type == :json
    end

    test "date attribute becomes date" do
      field = FormInfo.field(AutoFieldsForm, :birthday)
      assert field.type == :date
    end

    test "atom attribute (with one_of) becomes select with auto-populated options" do
      field = FormInfo.field(AutoFieldsForm, :status)
      assert field.type == :select
      assert field.options == [{"Active", :active}, {"Inactive", :inactive}]
    end

    test "datetime timestamps become datetime" do
      field = FormInfo.field(AutoFieldsForm, :inserted_at)
      assert field.type == :datetime
    end
  end

  describe "override type" do
    test ":age overridden to :range" do
      field = FormInfo.field(AutoFieldsForm, :age)
      assert field.type == :range
    end
  end

  describe "override options" do
    test ":age override sets required to true" do
      field = FormInfo.field(AutoFieldsForm, :age)
      assert field.required == true
    end
  end

  describe "override UI" do
    test ":bio override sets label" do
      field = FormInfo.field(AutoFieldsForm, :bio)
      assert field.ui != nil
      assert field.ui.label == "Biography"
    end

    test ":bio override sets rows" do
      field = FormInfo.field(AutoFieldsForm, :bio)
      assert field.ui.rows == 8
    end
  end
end
