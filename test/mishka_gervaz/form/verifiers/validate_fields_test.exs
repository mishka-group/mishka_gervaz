defmodule MishkaGervaz.Form.Verifiers.ValidateFieldsTest do
  @moduledoc """
  Tests for the ValidateFields verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost

  describe "positive: valid fields" do
    test "FormPost compiles with all fields referencing valid attributes" do
      fields = FormInfo.fields(FormPost)
      assert length(fields) == 7

      names = Enum.map(fields, & &1.name)
      assert :title in names
      assert :content in names
      assert :status in names
      assert :language in names
      assert :priority in names
      assert :featured in names
      assert :metadata in names
    end
  end

  describe "positive: virtual bypass" do
    test "virtual:true field passes without being in attributes" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.VirtualBypass#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :virtual_bypass_#{unique_id}
              route "/admin/virtual-bypass-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text
              field :computed_display, :text do
                virtual true
              end
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(code)
      end)

      module = Module.concat(MishkaGervaz.Test, :"VirtualBypass#{unique_id}")
      fields = FormInfo.fields(module)
      virtual_field = Enum.find(fields, &(&1.name == :computed_display))
      assert virtual_field != nil
      assert virtual_field.virtual == true
    end
  end

  describe "negative: not a resource attribute" do
    test "emits DslError for non-existent non-virtual field" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.BadFieldRef#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :bad_field_ref_#{unique_id}
              route "/admin/bad-field-ref-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text
              field :non_existent_attr, :text
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "is not a resource attribute"
      assert output =~ "non_existent_attr"
    end
  end

  describe "negative: depends_on undefined" do
    test "emits DslError for depends_on referencing non-existent field" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.BadDependsOn#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :bad_depends_on_#{unique_id}
              route "/admin/bad-depends-on-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text do
                depends_on :non_existent_field
              end
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "depends_on"
      assert output =~ "non_existent_field"
      assert output =~ "not a defined field"
    end
  end

  describe "negative: virtual relation without resource" do
    test "emits DslError for virtual :relation without resource option" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.VirtualRelNoRes#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :virt_rel_#{unique_id}
              route "/admin/virt-rel-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text
              field :category, :relation do
                virtual true
              end
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "requires `resource` option"
      assert output =~ "category"
    end
  end

  describe "negative: virtual select without resource" do
    test "emits DslError for virtual :select without resource option" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.VirtualSelNoRes#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :virt_sel_#{unique_id}
              route "/admin/virt-sel-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text
              field :tag, :select do
                virtual true
              end
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "requires `resource` option"
      assert output =~ "tag"
    end
  end
end
