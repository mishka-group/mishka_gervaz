defmodule MishkaGervaz.Table.Verifiers.ValidateRowActions do
  @moduledoc """
  Validates the row_actions section of MishkaGervaz DSL.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.{RowAction, RowActionDropdown}
  @path [:mishka_gervaz, :table, :row_actions]

  @impl true
  def verify(dsl_state) do
    entities = dsl_state |> Verifier.get_entities(@path) |> List.wrap()
    actions = Enum.filter(entities, &match?(%RowAction{}, &1))
    dropdowns = Enum.filter(entities, &match?(%RowActionDropdown{}, &1))

    with :ok <- validate_configs(actions, &validate_action/1, dsl_state),
         :ok <- validate_configs(dropdowns, &validate_dropdown/1, dsl_state),
         do: :ok
  end

  @spec validate_configs(list(), (map() -> list(String.t())), Spark.Dsl.t()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_configs(entities, validator, dsl_state) do
    entities
    |> Enum.flat_map(validator)
    |> maybe_config_error(dsl_state)
  end

  @spec maybe_config_error(list(String.t()), Spark.Dsl.t()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp maybe_config_error([], _dsl_state), do: :ok
  defp maybe_config_error(errors, dsl_state), do: dsl_error(dsl_state, Enum.join(errors, "; "))

  @spec dsl_error(Spark.Dsl.t(), String.t()) :: {:error, Spark.Error.DslError.t()}
  defp dsl_error(dsl_state, message) do
    {:error,
     Spark.Error.DslError.exception(
       module: Verifier.get_persisted(dsl_state, :module),
       path: @path,
       message: message
     )}
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
