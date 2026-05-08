defmodule MishkaGervaz.Form.Verifiers.ValidateUploads do
  @moduledoc """
  Validates the `uploads` section of MishkaGervaz form DSL.

  Four checks, in order:

    1. `field` reference (when set) names a field declared in the form.
    2. `accept` is a valid HTML accept string or list of MIME types /
       extensions (e.g. `"image/*,.pdf"` or `[".pdf", "image/*"]`).
    3. When `external` points to a module, that module is loadable.
       Anonymous-function externals are passed through.
    4. When `writer` is set, the writer module is loadable.

  See `MishkaGervaz.Form.Dsl.Uploads`,
  `MishkaGervaz.Form.Entities.Upload`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Field, Upload}

  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @fields_path [:mishka_gervaz, :form, :fields]
  @uploads_path [:mishka_gervaz, :form, :uploads]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    field_names = dsl_state |> entities_of(@fields_path, Field) |> Enum.map(& &1.name)
    uploads = entities_of(dsl_state, @uploads_path, Upload)

    with :ok <- validate_field_references(uploads, field_names, module),
         :ok <- validate_accept_formats(uploads, module),
         :ok <- validate_external_modules(uploads, module),
         :ok <- validate_writer_modules(uploads, module),
         do: :ok
  end

  defp validate_field_references(uploads, field_names, module) do
    Enum.find_value(uploads, :ok, &check_field_reference(&1, field_names, module))
  end

  defp check_field_reference(%{field: nil}, _field_names, _module), do: nil

  defp check_field_reference(%{field: field} = upload, field_names, module) do
    if field in field_names do
      nil
    else
      dsl_error(
        module,
        @uploads_path ++ [upload.name],
        "Upload `#{upload.name}` references field `#{field}` which doesn't exist."
      )
    end
  end

  defp validate_accept_formats(uploads, module) do
    Enum.find_value(uploads, :ok, &check_accept_format(&1, module))
  end

  defp check_accept_format(%{accept: nil}, _module), do: nil

  defp check_accept_format(upload, module) do
    if valid_accept_format?(upload.accept) do
      nil
    else
      dsl_error(
        module,
        @uploads_path ++ [upload.name],
        "Upload `#{upload.name}` has invalid accept format `#{inspect(upload.accept)}`. " <>
          "Expected comma-separated MIME types or extensions (e.g. \"image/*,.pdf\")."
      )
    end
  end

  defp validate_external_modules(uploads, module) do
    Enum.find_value(uploads, :ok, &check_external_module(&1, module))
  end

  defp check_external_module(%{external: nil}, _module), do: nil

  defp check_external_module(%{external: fun}, _module) when is_function(fun, 2), do: nil

  defp check_external_module(%{external: ext} = upload, module) when is_atom(ext) do
    if Code.ensure_loaded?(ext) do
      nil
    else
      dsl_error(
        module,
        @uploads_path ++ [upload.name],
        "Upload `#{upload.name}` references external module `#{inspect(ext)}` which could not be loaded."
      )
    end
  end

  defp check_external_module(_upload, _module), do: nil

  defp validate_writer_modules(uploads, module) do
    Enum.find_value(uploads, :ok, &check_writer_module(&1, module))
  end

  defp check_writer_module(%{writer: nil}, _module), do: nil

  defp check_writer_module(%{writer: writer} = upload, module) do
    if Code.ensure_loaded?(writer) do
      nil
    else
      dsl_error(
        module,
        @uploads_path ++ [upload.name],
        "Upload `#{upload.name}` references writer module `#{inspect(writer)}` which could not be loaded."
      )
    end
  end

  defp valid_accept_format?(accept) when is_list(accept) do
    Enum.all?(accept, &valid_accept_part?/1)
  end

  defp valid_accept_format?(accept) when is_binary(accept) do
    accept
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.all?(&(&1 == "" or valid_accept_part?(&1)))
  end

  defp valid_accept_format?(_), do: false

  defp valid_accept_part?(part) when is_binary(part) do
    String.starts_with?(part, ".") or String.contains?(part, "/")
  end

  defp valid_accept_part?(_), do: false
end
