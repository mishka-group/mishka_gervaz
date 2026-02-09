defmodule MishkaGervaz.Form.Verifiers.ValidateUploadsTest do
  @moduledoc """
  Tests for the ValidateUploads verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost

  describe "positive: valid upload" do
    test "FormPost upload compiles with nil field" do
      uploads = FormInfo.uploads(FormPost)
      cover = Enum.find(uploads, &(&1.name == :cover))
      assert cover != nil
      assert cover.field == nil
    end
  end

  describe "positive: valid field reference" do
    test "upload with field referencing existing field compiles" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.UploadValidField#{unique_id} do
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
              name :upload_valid_#{unique_id}
              route "/admin/upload-valid-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text
            end

            uploads do
              upload :avatar do
                field :title
                accept "image/*"
              end
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(code)
      end)

      module = Module.concat(MishkaGervaz.Test, :"UploadValidField#{unique_id}")
      uploads = FormInfo.uploads(module)
      avatar = Enum.find(uploads, &(&1.name == :avatar))
      assert avatar != nil
      assert avatar.field == :title
    end
  end

  describe "negative: bad field reference" do
    test "emits DslError for upload referencing non-existent field" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.UploadBadField#{unique_id} do
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
              name :upload_bad_#{unique_id}
              route "/admin/upload-bad-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            fields do
              field :title, :text
            end

            uploads do
              upload :doc do
                field :non_existent_field
                accept "application/pdf"
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

      assert output =~ "references field"
      assert output =~ "non_existent_field"
      assert output =~ "doesn't exist"
    end
  end
end
