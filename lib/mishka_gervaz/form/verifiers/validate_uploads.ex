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

    with :ok <- validate_field_references(uploads, field_names, module),
         :ok <- validate_accept_formats(uploads, module),
         :ok <- validate_external_modules(uploads, module),
         :ok <- validate_writer_modules(uploads, module) do
      :ok
    end
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

  @spec validate_accept_formats([Upload.t()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_accept_formats(uploads, module) do
    Enum.reduce_while(uploads, :ok, fn upload, :ok ->
      if upload.accept == nil or valid_accept_format?(upload.accept) do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @uploads_path ++ [upload.name],
            message:
              "Upload `#{upload.name}` has invalid accept format `#{upload.accept}`. " <>
                "Expected comma-separated MIME types or extensions (e.g. \"image/*,.pdf\")."
          )}}
      end
    end)
  end

  @spec validate_external_modules([Upload.t()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_external_modules(uploads, module) do
    Enum.reduce_while(uploads, :ok, fn upload, :ok ->
      cond do
        upload.external == nil ->
          {:cont, :ok}

        is_atom(upload.external) ->
          if Code.ensure_loaded?(upload.external) do
            {:cont, :ok}
          else
            {:halt,
             {:error,
              Spark.Error.DslError.exception(
                module: module,
                path: @uploads_path ++ [upload.name],
                message:
                  "Upload `#{upload.name}` references external module `#{inspect(upload.external)}` which could not be loaded."
              )}}
          end

        is_function(upload.external, 2) ->
          {:cont, :ok}

        true ->
          {:cont, :ok}
      end
    end)
  end

  @spec validate_writer_modules([Upload.t()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_writer_modules(uploads, module) do
    Enum.reduce_while(uploads, :ok, fn upload, :ok ->
      if upload.writer == nil or Code.ensure_loaded?(upload.writer) do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @uploads_path ++ [upload.name],
            message:
              "Upload `#{upload.name}` references writer module `#{inspect(upload.writer)}` which could not be loaded."
          )}}
      end
    end)
  end

  defp valid_accept_format?(accept) when is_list(accept) do
    Enum.all?(accept, fn part ->
      is_binary(part) and
        (String.starts_with?(part, ".") or String.contains?(part, "/"))
    end)
  end

  defp valid_accept_format?(accept) when is_binary(accept) do
    accept
    |> String.split(",")
    |> Enum.all?(fn part ->
      trimmed = String.trim(part)
      trimmed == "" or String.starts_with?(trimmed, ".") or String.contains?(trimmed, "/")
    end)
  end

  defp valid_accept_format?(_), do: false
end
