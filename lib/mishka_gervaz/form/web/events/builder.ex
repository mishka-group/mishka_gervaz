defmodule MishkaGervaz.Form.Web.Events.Builder do
  @moduledoc """
  Common macro for all form Events sub-builders.

  Provides consistent structure and defoverridable pattern for:
  - ValidationHandler
  - SubmitHandler
  - StepHandler
  - UploadHandler
  - RelationHandler
  - HookRunner
  - SanitizationHandler
  """

  @spec parse_typed_params(list(), map()) :: map()
  def parse_typed_params(fields, params) when is_list(fields) and is_map(params) do
    Enum.reduce(fields, params, fn field, acc ->
      field_name = to_string(field.name)

      case Map.fetch(acc, field_name) do
        {:ok, value} ->
          type_mod = Map.get(field, :type_module)

          if type_mod && function_exported?(type_mod, :parse_params, 2) do
            Map.put(acc, field_name, type_mod.parse_params(value, field))
          else
            acc
          end

        :error ->
          acc
      end
    end)
  end

  def parse_typed_params(_, params), do: params

  @spec sanitize_typed_params(list(), map()) :: map()
  def sanitize_typed_params(fields, params) when is_list(fields) and is_map(params) do
    Enum.reduce(fields, params, fn field, acc ->
      field_name = to_string(field.name)

      case Map.fetch(acc, field_name) do
        {:ok, value} ->
          type_mod = Map.get(field, :type_module)

          if type_mod && function_exported?(type_mod, :sanitize, 2) do
            Map.put(acc, field_name, type_mod.sanitize(value, field))
          else
            acc
          end

        :error ->
          acc
      end
    end)
  end

  def sanitize_typed_params(_, params), do: params

  defmacro __using__(_opts) do
    quote do
      @spec __builder_info__(:module) :: module()
      def __builder_info__(:module), do: __MODULE__
    end
  end
end
