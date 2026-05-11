defmodule MishkaGervaz.Table.Verifiers.ValidateColumns do
  @moduledoc """
  Validates the columns section of MishkaGervaz DSL.

  Ensures that:
  - At least one column exists after all transformers have run
  - Custom columns (not in resource attributes) have `static: true`
  - Static columns with render have `requires` defined

  See `MishkaGervaz.Table.Dsl.Columns`,
  `MishkaGervaz.Table.Entities.Column`,
  `MishkaGervaz.Table.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.Column
  import MishkaGervaz.Table.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @path [:mishka_gervaz, :table, :columns]

  @impl true
  def verify(dsl_state) do
    if is_nil(Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :identity], :route)) do
      :ok
    else
      module = Verifier.get_persisted(dsl_state, :module)
      columns = entities_of(dsl_state, @path, Column)
      fields = get_resource_fields(module)

      with :ok <- validate_columns_exist(columns, module),
           :ok <- validate_static_columns(columns, fields, module),
           do: :ok
    end
  end

  @spec get_resource_fields(module()) :: [atom()]
  defp get_resource_fields(module) do
    if function_exported?(module, :spark_dsl_config, 0) do
      [
        Ash.Resource.Info.attributes(module),
        Ash.Resource.Info.relationships(module),
        Ash.Resource.Info.calculations(module),
        Ash.Resource.Info.aggregates(module)
      ]
      |> List.flatten()
      |> Enum.map(& &1.name)
    else
      []
    end
  rescue
    _ -> []
  end

  @spec validate_columns_exist(list(), module()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_columns_exist([], module),
    do: dsl_error(module, @path, no_columns_message())

  defp validate_columns_exist(_columns, _module), do: :ok

  @spec validate_static_columns([Column.t()], [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_static_columns(columns, fields, module) do
    Enum.find_value(columns, :ok, &check_column(&1, fields, module))
  end

  defp check_column(column, fields, module) do
    is_field = column.name in fields
    has_custom_source = has_custom_source?(column)
    has_render = not is_nil(column.render)
    has_requires = column.requires != [] and not is_nil(column.requires)
    sort_field_val = Map.get(column, :sort_field, [])
    has_sort_field = sort_field_val != [] and not is_nil(sort_field_val)

    cond do
      column.static and column.sortable and not has_sort_field ->
        dsl_error(module, @path ++ [column.name], static_sortable_message(column))

      column.sortable and has_sort_field ->
        invalid_sort_fields(column, fields, module)

      is_field ->
        nil

      has_custom_source ->
        nil

      column.static and has_render and not has_requires ->
        dsl_error(module, @path ++ [column.name], static_needs_requires_message(column))

      not column.static and not is_field ->
        dsl_error(module, @path ++ [column.name], not_a_field_message(column))

      true ->
        nil
    end
  end

  defp invalid_sort_fields(column, fields, module) do
    case Enum.reject(Map.get(column, :sort_field, []), &(&1 in fields)) do
      [] ->
        nil

      invalid ->
        dsl_error(
          module,
          @path ++ [column.name],
          invalid_sort_field_message(column, invalid, fields)
        )
    end
  end

  @spec has_custom_source?(Column.t()) :: boolean()
  defp has_custom_source?(%{source: source, name: name}) when source != name, do: true
  defp has_custom_source?(_column), do: false

  defp no_columns_message do
    """
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
  end

  defp static_sortable_message(column) do
    """
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
  end

  defp static_needs_requires_message(column) do
    """
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
  end

  defp not_a_field_message(column) do
    """
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
  end

  defp invalid_sort_field_message(column, invalid, fields) do
    """
    Column `#{column.name}` has invalid sort_field values: #{inspect(invalid)}.

    The sort_field values must be existing resource attributes or relationships.
    Available fields: #{inspect(fields)}

        column :#{column.name} do
          sort_field #{inspect(Enum.filter(column.sort_field, &(&1 in fields)))}
        end
    """
  end
end
