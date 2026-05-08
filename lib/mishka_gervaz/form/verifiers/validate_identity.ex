defmodule MishkaGervaz.Form.Verifiers.ValidateIdentity do
  @moduledoc """
  Validates the `identity` section of MishkaGervaz form DSL.

  Ensures `identity.name` is set. The DSL schema marks `name` as required
  and `MishkaGervaz.Form.Transformers.MergeDefaults` derives a name from
  the resource module when omitted — this verifier is the final guarantee
  that the resolved value is not nil regardless of which path produced it.

  See `MishkaGervaz.Form.Dsl.Identity`,
  `MishkaGervaz.Form.Transformers.MergeDefaults`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3]

  @path [:mishka_gervaz, :form, :identity]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    validate_name(
      Verifier.get_option(dsl_state, @path, :name),
      Verifier.get_persisted(dsl_state, :module)
    )
  end

  defp validate_name(nil, module),
    do: dsl_error(module, @path ++ [:name], "form identity.name is required")

  defp validate_name(_name, _module), do: :ok
end
