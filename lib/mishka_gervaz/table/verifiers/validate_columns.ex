defmodule MishkaGervaz.Table.Verifiers.ValidateColumns do
  @moduledoc """
  Validates the columns section of MishkaGervaz DSL.

  Ensures that:
  - At least one column exists after all transformers have run
  - Custom columns (not in resource attributes) have `static: true`
  - Static columns with render have `requires` defined
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.Column

  @path [:mishka_gervaz, :table, :columns]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    entities = Spark.Dsl.Transformer.get_entities(dsl_state, @path)
    columns = Enum.filter(entities, &match?(%Column{}, &1))
    fields = get_resource_fields(module)

    with :ok <- validate_columns_exist(columns, module),
         :ok <- validate_static_columns(columns, fields, module) do
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

  @spec validate_columns_exist(list(), module()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_columns_exist([], module) do
    {:error,
     Spark.Error.DslError.exception(
       module: module,
       path: @path,
       message: """
       No columns defined for the table.

       You must define at least one column. Options:

       1. Use auto_columns to discover columns from resource attributes:

          columns do
            auto_columns do
              except [:id, :inserted_at]  # optional: exclude specific attributes
            end
          end

       2. Define explicit columns:

          columns do
            column :name, sortable: true
            column :status
          end

       3. Combine both approaches:

          columns do
            auto_columns do
              except [:id]
            end

            column :custom_field, render: fn record -> ... end
          end
       """
     )}
  end

  defp validate_columns_exist(_columns, _module), do: :ok

  @spec validate_static_columns([Column.t()], [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_static_columns(columns, fields, module) do
    Enum.reduce_while(columns, :ok, fn column, :ok ->
      case validate_single_column(column, fields, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @spec validate_single_column(Column.t(), [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_single_column(column, fields, module) do
    is_field = column.name in fields
    has_custom_source = has_custom_source?(column)
    has_render = not is_nil(column.render)
    has_requires = column.requires != [] and not is_nil(column.requires)
    sort_field_val = Map.get(column, :sort_field, [])
    has_sort_field = sort_field_val != [] and not is_nil(sort_field_val)

    cond do
      column.static and column.sortable and not has_sort_field ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: @path ++ [column.name],
           message: """
           Static sortable column `#{column.name}` must specify `sort_field`.

           Static columns with `sortable true` must declare which database field(s) to sort by:

               column :#{column.name} do
                 static true
                 sortable true
                 sort_field [:field_name]  # Add database field(s) to sort by
                 requires [:field1, :field2]
                 render fn record -> ... end
               end

           The `sort_field` option tells MishkaGervaz which actual database fields
           to use when this column is sorted, since static columns don't map
           directly to a database field.
           """
         )}

      column.sortable and has_sort_field ->
        validate_sort_fields(column, fields, module)

      is_field ->
        :ok

      has_custom_source ->
        :ok

      column.static and has_render and not has_requires ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: @path ++ [column.name],
           message: """
           Static column `#{column.name}` with render requires `requires` option.

           Static columns with a render function must specify which fields they need:

               column :#{column.name} do
                 static true
                 requires [:field1, :field2]  # Add required fields
                 render fn record -> ... end
               end

           The `requires` option tells MishkaGervaz which fields to include
           in the record passed to your render function.
           """
         )}

      not column.static and not is_field ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: @path ++ [column.name],
           message: """
           Column `#{column.name}` is not a resource field.

           The column name `#{column.name}` doesn't exist as an attribute or relationship.

           If this is a custom/computed column, add `static: true`:

               column :#{column.name} do
                 static true
                 requires [:field1, :field2]
                 render fn record -> ... end
               end

           If you meant to reference an existing field, check the spelling
           or verify the field exists in your Ash resource.
           """
         )}

      true ->
        :ok
    end
  end

  @spec validate_sort_fields(Column.t(), [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_sort_fields(column, fields, module) do
    invalid = Enum.reject(Map.get(column, :sort_field, []), &(&1 in fields))

    if invalid == [] do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: @path ++ [column.name],
         message: """
         Column `#{column.name}` has invalid sort_field values: #{inspect(invalid)}.

         The sort_field values must be existing resource attributes or relationships.
         Available fields: #{inspect(fields)}

             column :#{column.name} do
               sort_field #{inspect(Enum.filter(column.sort_field, &(&1 in fields)))}
             end
         """
       )}
    end
  end

  @spec has_custom_source?(Column.t()) :: boolean()
  defp has_custom_source?(%{source: source, name: name}) when source != name, do: true
  defp has_custom_source?(_column), do: false
end
