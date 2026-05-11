defmodule MishkaGervaz.Table.Verifiers.ValidateRowActions do
  @moduledoc """
  Validates the row_actions section of MishkaGervaz DSL.

  See `MishkaGervaz.Table.Dsl.RowActions`,
  `MishkaGervaz.Table.Entities.RowAction`,
  `MishkaGervaz.Table.Entities.RowActionDropdown`,
  `MishkaGervaz.Table.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.{RowAction, RowActionDropdown}
  import MishkaGervaz.Table.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @path [:mishka_gervaz, :table, :row_actions]

  @impl true
  def verify(dsl_state) do
    if is_nil(Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :identity], :route)) do
      :ok
    else
      do_verify(dsl_state)
    end
  end

  defp do_verify(dsl_state) do
    actions = entities_of(dsl_state, @path, RowAction)
    dropdowns = entities_of(dsl_state, @path, RowActionDropdown)
    module = Verifier.get_persisted(dsl_state, :module)

    with :ok <- validate_configs(actions, &validate_action/1, module),
         :ok <- validate_configs(dropdowns, &validate_dropdown/1, module),
         do: :ok
  end

  @spec validate_configs(list(), (map() -> list(String.t())), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_configs(entities, validator, module) do
    entities
    |> Enum.flat_map(validator)
    |> case do
      [] -> :ok
      errors -> dsl_error(module, @path, Enum.join(errors, "; "))
    end
  end

  @spec validate_action(map()) :: list(String.t())
  defp validate_action(%{type: :link, path: nil, name: name}),
    do: ["Action #{inspect(name)} of type :link requires a :path option"]

  defp validate_action(%{type: :event, event: nil, name: name}),
    do: ["Action #{inspect(name)} of type :event requires an :event option"]

  defp validate_action(_), do: []

  @spec validate_dropdown(map()) :: list(String.t())
  defp validate_dropdown(%{name: name, ui: []}),
    do: ["Dropdown #{inspect(name)} requires a ui block with label"]

  defp validate_dropdown(%{name: name, ui: [%{label: nil}]}),
    do: ["Dropdown #{inspect(name)} requires a label in ui block"]

  defp validate_dropdown(%{items: items, name: name}) when is_list(items) do
    items
    |> Enum.filter(&match?(%RowAction{}, &1))
    |> Enum.flat_map(&validate_action/1)
    |> Enum.map(&"In dropdown #{inspect(name)}: #{&1}")
  end

  defp validate_dropdown(_), do: []
end
