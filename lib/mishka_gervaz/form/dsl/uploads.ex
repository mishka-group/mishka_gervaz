defmodule MishkaGervaz.Form.Dsl.Uploads do
  @moduledoc """
  Uploads section — file upload entities tied to fields of type
  `:upload`.

  Each `upload` entity declares accept rules, count and size limits, and
  optional dropzone text and preview UI. A `field :name, :upload` with a
  matching name binds the LiveView upload config to the rendered control.

  ## Example

      uploads do
        upload :cover do
          accept "image/*"
          max_entries 1
          max_file_size 5_000_000
          show_preview true
          auto_upload true
          dropzone_text "Drop image here"

          ui do
            label "Cover Image"
            icon "hero-photo"
            class "border-dashed"
            preview_class "w-32 h-32"
          end
        end
      end

  See `MishkaGervaz.Form.Entities.Upload` for the full option list,
  including `auto_upload`, `chunk_size`, `progress`, and the `ui`
  sub-entity.
  """

  alias MishkaGervaz.Form.Entities.Upload

  defp upload_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI configuration for the upload.",
      target: Upload.Ui,
      schema: Upload.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Upload.Ui, :transform, []}
    }
  end

  defp upload_entity do
    %Spark.Dsl.Entity{
      name: :upload,
      describe: "Define a file upload.",
      target: Upload,
      args: [:name],
      identifier: :name,
      schema: Upload.opt_schema(),
      entities: [ui: [upload_ui_entity()]],
      transform: {Upload, :transform, []}
    }
  end

  @doc """
  Returns the uploads section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :uploads,
      describe: "File upload configuration.",
      entities: [upload_entity()]
    }
  end
end
