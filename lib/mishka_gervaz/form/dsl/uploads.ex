defmodule MishkaGervaz.Form.Dsl.Uploads do
  @moduledoc """
  Uploads section DSL definition for form configuration.

  Defines file upload configuration for form fields.
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
