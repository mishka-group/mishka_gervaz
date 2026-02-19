defmodule MishkaGervaz.Form.Verifiers.ValidateFields do
  @moduledoc """
  Validates the fields section of MishkaGervaz form DSL.

  Ensures that:
  - Field names exist as resource attributes or are marked virtual
  - depends_on references exist
  - Virtual fields have resource set when needed
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.Field

  @path [:mishka_gervaz, :form, :fields]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    fields =
      Spark.Dsl.Transformer.get_entities(dsl_state, @path) |> Enum.filter(&match?(%Field{}, &1))

    resource_fields = get_resource_fields(module)
    field_names = Enum.map(fields, & &1.name)

    with :ok <- validate_field_references(fields, resource_fields, module),
         :ok <- validate_depends_on(fields, field_names, module),
         :ok <- validate_virtual_fields(fields, module),
         :ok <- validate_nested_field_placement(fields, module) do
      :ok
    end
  end

  @spec get_resource_fields(module()) :: [atom()]
  defp get_resource_fields(module) do
    if function_exported?(module, :spark_dsl_config, 0) do
      try do
        attributes = Ash.Resource.Info.attributes(module) |> Enum.map(& &1.name)
        relationships = Ash.Resource.Info.relationships(module) |> Enum.map(& &1.name)
        calculations = Ash.Resource.Info.calculations(module) |> Enum.map(& &1.name)
        aggregates = Ash.Resource.Info.aggregates(module) |> Enum.map(& &1.name)
        attributes ++ relationships ++ calculations ++ aggregates
      rescue
        _ -> []
      end
    else
      []
    end
  end

  @spec validate_field_references([Field.t()], [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_field_references(fields, resource_fields, module) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      if field.virtual or field.name in resource_fields do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @path ++ [field.name],
            message: """
            Field `#{field.name}` is not a resource attribute.

            If this is a computed/virtual field, add `virtual: true`:

                field :#{field.name}, :text do
                  virtual true
                end
            """
          )}}
      end
    end)
  end

  @spec validate_depends_on([Field.t()], [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_depends_on(fields, field_names, module) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      if field.depends_on == nil or field.depends_on in field_names do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @path ++ [field.name],
            message:
              "Field `#{field.name}` depends_on `#{field.depends_on}` which is not a defined field."
          )}}
      end
    end)
  end

  @spec validate_virtual_fields([Field.t()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_virtual_fields(fields, module) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      if field.virtual and field.type in [:relation, :select] and is_nil(field.resource) do
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @path ++ [field.name],
            message: """
            Virtual field `#{field.name}` of type `#{field.type}` requires `resource` option.

                field :#{field.name}, :#{field.type} do
                  virtual true
                  resource MyApp.SomeResource
                end
            """
          )}}
      else
        {:cont, :ok}
      end
    end)
  end

  @spec validate_nested_field_placement([Field.t()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_nested_field_placement(fields, module) do
    alias MishkaGervaz.Form.Entities.NestedField

    Enum.reduce_while(fields, :ok, fn field, :ok ->
      has_nested_entities? =
        is_list(field.nested_fields) and
          Enum.any?(field.nested_fields, &is_struct(&1, NestedField))

      if has_nested_entities? and field.type not in [:nested, nil] do
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @path ++ [field.name],
            message: """
            `nested_field` is only allowed inside fields with type `:nested`.

            Field `#{field.name}` has type `#{inspect(field.type)}`.
            Either change the type to `:nested` or remove the nested_field entries.
            """
          )}}
      else
        {:cont, :ok}
      end
    end)
  end
end
