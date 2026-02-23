defmodule MishkaGervaz.Form.Verifiers.ValidateGroups do
  @moduledoc """
  Validates the groups section of MishkaGervaz form DSL.

  Ensures that:
  - All group field references exist in defined fields
  - No field appears in multiple groups
  - Group names are unique
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Field, Group}

  @fields_path [:mishka_gervaz, :form, :fields]
  @groups_path [:mishka_gervaz, :form, :groups]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    field_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @fields_path)
    fields = Enum.filter(field_entities, &match?(%Field{}, &1))
    field_names = Enum.map(fields, & &1.name)

    group_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @groups_path)
    groups = Enum.filter(group_entities, &match?(%Group{}, &1))

    with :ok <- validate_field_references(groups, field_names, module),
         :ok <- validate_no_duplicate_fields(groups, module) do
      :ok
    end
  end

  @spec validate_field_references([Group.t()], [atom()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_field_references(groups, field_names, module) do
    Enum.reduce_while(groups, :ok, fn group, :ok ->
      missing = Enum.reject(group.fields, &(&1 in field_names))

      if missing == [] do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @groups_path ++ [group.name],
            message:
              "Group `#{group.name}` references fields that don't exist: #{inspect(missing)}"
          )}}
      end
    end)
  end

  @spec validate_no_duplicate_fields([Group.t()], module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_no_duplicate_fields(groups, module) do
    {_, result} =
      Enum.reduce_while(groups, {MapSet.new(), :ok}, fn group, {seen, :ok} ->
        duplicates = Enum.filter(group.fields, &MapSet.member?(seen, &1))

        if duplicates == [] do
          new_seen = Enum.reduce(group.fields, seen, &MapSet.put(&2, &1))
          {:cont, {new_seen, :ok}}
        else
          {:halt,
           {seen,
            {:error,
             Spark.Error.DslError.exception(
               module: module,
               path: @groups_path ++ [group.name],
               message:
                 "Group `#{group.name}` contains fields already in another group: #{inspect(duplicates)}"
             )}}}
        end
      end)

    result
  end
end
