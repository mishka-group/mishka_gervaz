defmodule MishkaGervaz.Form.Types.Field.UploadFieldTypeTest do
  @moduledoc """
  Tests for the :upload field type — inline upload positioning.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Form.Types.Field, as: FieldTypeRegistry
  alias MishkaGervaz.Form.Types.Field.Upload, as: UploadType

  alias MishkaGervaz.Test.Resources.{
    UploadFieldForm,
    FormPost
  }

  describe "Upload type module behaviour" do
    test "render/2 passes through assigns" do
      assigns = %{name: :test}
      assert UploadType.render(assigns, %{}) == assigns
    end

    test "validate/2 returns {:ok, value}" do
      assert UploadType.validate("file.png", %{}) == {:ok, "file.png"}
    end

    test "parse_params/2 passes through value" do
      assert UploadType.parse_params("raw", %{}) == "raw"
    end

    test "default_ui/0 returns upload type map" do
      assert UploadType.default_ui() == %{type: :upload}
    end
  end

  describe "type registry" do
    test ":upload resolves to Field.Upload in registry" do
      result = FieldTypeRegistry.get(:upload)
      assert result == MishkaGervaz.Form.Types.Field.Upload
    end

    test ":upload is a builtin type" do
      assert FieldTypeRegistry.builtin?(:upload)
    end
  end

  describe "DSL compilation with :upload field" do
    test "UploadFieldForm compiles and has 3 fields" do
      fields = FormInfo.fields(UploadFieldForm)
      assert length(fields) == 3
    end

    test ":cover field has type :upload" do
      field = FormInfo.field(UploadFieldForm, :cover)
      assert field.type == :upload
    end

    test ":cover field is automatically virtual" do
      field = FormInfo.field(UploadFieldForm, :cover)
      assert field.virtual == true
    end

    test ":cover field has type_module resolved" do
      field = FormInfo.field(UploadFieldForm, :cover)
      assert field.type_module == MishkaGervaz.Form.Types.Field.Upload
    end

    test ":cover field source defaults to :cover" do
      field = FormInfo.field(UploadFieldForm, :cover)
      assert field.source == :cover
    end
  end

  describe "group resolution with :upload field" do
    test "group :main includes :cover in fields list" do
      groups = FormInfo.groups(UploadFieldForm)
      main_group = Enum.find(groups, fn g -> g.name == :main end)
      assert :cover in main_group.fields
    end

    test "group field order matches DSL order" do
      groups = FormInfo.groups(UploadFieldForm)
      main_group = Enum.find(groups, fn g -> g.name == :main end)
      assert main_group.fields == [:title, :cover, :content]
    end
  end

  describe "inline_upload_names filtering" do
    test "FormPost has no inline upload fields (uploads render at bottom)" do
      fields = FormInfo.fields(FormPost)
      inline = Enum.filter(fields, fn f -> f.type == :upload end)
      assert inline == []
    end

    test "UploadFieldForm has one inline upload field" do
      fields = FormInfo.fields(UploadFieldForm)
      inline = Enum.filter(fields, fn f -> f.type == :upload end)
      assert length(inline) == 1
      assert hd(inline).name == :cover
    end
  end
end
