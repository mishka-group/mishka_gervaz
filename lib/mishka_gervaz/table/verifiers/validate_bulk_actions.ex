defmodule MishkaGervaz.Table.Verifiers.ValidateBulkActions do
  @moduledoc """
  Validates the bulk_actions section of MishkaGervaz DSL.

  Ensures:
  - When bulk_actions section exists, at least one action is defined

  See `MishkaGervaz.Table.Dsl.BulkActions`,
  `MishkaGervaz.Table.Entities.BulkAction`,
  `MishkaGervaz.Table.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.BulkAction
  import MishkaGervaz.Table.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @path [:mishka_gervaz, :table, :bulk_actions]

  @impl true
  def verify(dsl_state) do
    if is_nil(Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :identity], :route)) do
      :ok
    else
      actions = entities_of(dsl_state, @path, BulkAction)

      (Verifier.get_option(dsl_state, @path, :enabled) != nil or actions != [])
      |> validate_at_least_one_action(actions, dsl_state)
    end
  end

  @spec validate_at_least_one_action(boolean(), list(), Spark.Dsl.t()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_at_least_one_action(false, _actions, _dsl_state), do: :ok

  defp validate_at_least_one_action(true, [], dsl_state) do
    dsl_error(
      Verifier.get_persisted(dsl_state, :module),
      @path,
      """
      bulk_actions section requires at least one action.

      Example:
        bulk_actions do
          action :delete do
            confirm "Delete {count} items?"
            event :bulk_delete
          end
        end
      """
    )
  end

  defp validate_at_least_one_action(true, _actions, _dsl_state), do: :ok
end
