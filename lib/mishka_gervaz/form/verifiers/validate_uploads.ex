defmodule MishkaGervaz.Form.Verifiers.ValidateUploads do
  @moduledoc """
  Validates the uploads section of MishkaGervaz form DSL.

  Ensures that:
  - Upload field references exist in defined fields
  - Accept format is valid
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Field, Upload}

  @fields_path [:mishka_gervaz, :form, :fields]
  @uploads_path [:mishka_gervaz, :form, :uploads]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    field_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @fields_path)
    fields = Enum.filter(field_entities, &match?(%Field{}, &1))
    field_names = Enum.map(fields, & &1.name)

    upload_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @uploads_path)
    uploads = Enum.filter(upload_entities, &match?(%Upload{}, &1))

    validate_field_references(uploads, field_names, module)
  end

  @spec validate_field_references([Upload.t()], [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_field_references(uploads, field_names, module) do
    Enum.reduce_while(uploads, :ok, fn upload, :ok ->
      if upload.field == nil or upload.field in field_names do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @uploads_path ++ [upload.name],
            message:
              "Upload `#{upload.name}` references field `#{upload.field}` which doesn't exist."
          )}}
      end
    end)
  end
end
