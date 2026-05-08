defmodule MishkaGervaz.Form.Verifiers.Helpers do
  @moduledoc """
  Shared helpers for `MishkaGervaz.Form.Verifiers.*`.

  Removes duplication of the `Spark.Error.DslError` wrap and the
  fetch-then-filter-by-struct boilerplate that recurs across every verifier.

  Mirrors `MishkaGervaz.Table.Transformers.Helpers` in spirit — small,
  composable, no behaviour-specific logic.

  See sibling verifier modules:
  `MishkaGervaz.Form.Verifiers.ValidateIdentity`,
  `MishkaGervaz.Form.Verifiers.ValidateSource`,
  `MishkaGervaz.Form.Verifiers.ValidateFields`,
  `MishkaGervaz.Form.Verifiers.ValidateGroups`,
  `MishkaGervaz.Form.Verifiers.ValidateUploads`,
  `MishkaGervaz.Form.Verifiers.ValidateChrome`,
  `MishkaGervaz.Form.Verifiers.ValidateSteps`,
  `MishkaGervaz.Form.Verifiers.ValidatePreloads`.
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
