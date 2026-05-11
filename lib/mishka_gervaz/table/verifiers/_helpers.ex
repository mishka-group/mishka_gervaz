defmodule MishkaGervaz.Table.Verifiers.Helpers do
  @moduledoc """
  Shared helpers for `MishkaGervaz.Table.Verifiers.*`.

  Removes duplication of the `Spark.Error.DslError` wrap and the
  fetch-then-filter-by-struct boilerplate that recurs across every verifier.

  Mirrors `MishkaGervaz.Form.Verifiers.Helpers` — small, composable,
  no behaviour-specific logic.

  See sibling verifier modules:
  `MishkaGervaz.Table.Verifiers.ValidateIdentity`,
  `MishkaGervaz.Table.Verifiers.ValidateSource`,
  `MishkaGervaz.Table.Verifiers.ValidateColumns`,
  `MishkaGervaz.Table.Verifiers.ValidateFilters`,
  `MishkaGervaz.Table.Verifiers.ValidateRowActions`,
  `MishkaGervaz.Table.Verifiers.ValidateBulkActions`,
  `MishkaGervaz.Table.Verifiers.ValidatePagination`,
  `MishkaGervaz.Table.Verifiers.ValidateLayout`,
  `MishkaGervaz.Table.Verifiers.ValidateDomainDefaults`.
  """

  alias Spark.Dsl.Transformer

  @doc """
  Wraps a `Spark.Error.DslError` as `{:error, exception}`.
  """
  @spec dsl_error(module(), [atom()], String.t()) :: {:error, Spark.Error.DslError.t()}
  def dsl_error(module, path, message) do
    {:error, Spark.Error.DslError.exception(module: module, path: path, message: message)}
  end

  @doc """
  Fetches entities at `path` and keeps only those of `struct_type`.

  Always returns a list; safely unwraps Spark's nil/list-of-lists shapes.
  """
  @spec entities_of(Spark.Dsl.t(), [atom()], module()) :: [struct()]
  def entities_of(dsl_state, path, struct_type) do
    dsl_state
    |> Transformer.get_entities(path)
    |> List.wrap()
    |> Enum.filter(&is_struct(&1, struct_type))
  end
end
