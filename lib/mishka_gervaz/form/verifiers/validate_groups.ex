defmodule MishkaGervaz.Form.Verifiers.ValidateGroups do
  @moduledoc """
  Validates the `groups` section of MishkaGervaz form DSL.

  Two checks:

    1. Every group field reference exists in the form's declared fields.
    2. No field appears in more than one group (groups partition fields).

  See `MishkaGervaz.Form.Dsl.Groups`,
  `MishkaGervaz.Form.Entities.Group`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Field, Group}

  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @fields_path [:mishka_gervaz, :form, :fields]
  @groups_path [:mishka_gervaz, :form, :groups]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    field_names = dsl_state |> entities_of(@fields_path, Field) |> Enum.map(& &1.name)
    groups = entities_of(dsl_state, @groups_path, Group)

    with :ok <- validate_field_references(groups, field_names, module),
         :ok <- validate_no_duplicate_fields(groups, module),
         do: :ok
  end

  defp validate_field_references(groups, field_names, module) do
    Enum.find_value(groups, :ok, &check_field_references(&1, field_names, module))
  end

  defp check_field_references(group, field_names, module) do
    case Enum.reject(group.fields, &(&1 in field_names)) do
      [] ->
        nil

      missing ->
        dsl_error(
          module,
          @groups_path ++ [group.name],
          "Group `#{group.name}` references fields that don't exist: #{inspect(missing)}"
        )
    end
  end

  defp validate_no_duplicate_fields(groups, module) do
    groups
    |> Enum.reduce_while({MapSet.new(), :ok}, &check_for_duplicates(&1, &2, module))
    |> elem(1)
  end

  defp check_for_duplicates(group, {seen, _}, module) do
    case Enum.filter(group.fields, &MapSet.member?(seen, &1)) do
      [] ->
        {:cont, {Enum.into(group.fields, seen), :ok}}

      dups ->
        {:halt,
         {seen, dsl_error(module, @groups_path ++ [group.name], duplicate_message(group, dups))}}
    end
  end

  defp duplicate_message(group, dups) do
    "Group `#{group.name}` contains fields already in another group: #{inspect(dups)}"
  end
end
