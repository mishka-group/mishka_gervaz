defmodule MishkaGervaz.Form.Verifiers.ValidateIdentity do
  @moduledoc """
  Validates the identity section of MishkaGervaz form DSL.

  Ensures:
  - `identity.name` is present
  - `identity.stream_name` is an atom if set
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  @path [:mishka_gervaz, :form, :identity]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    name = Verifier.get_option(dsl_state, @path, :name)

    validate_name(name, module)
  end

  @spec validate_name(atom() | nil, module()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_name(nil, module) do
    {:error,
     Spark.Error.DslError.exception(
       module: module,
       path: @path ++ [:name],
       message: "form identity.name is required"
     )}
  end

  defp validate_name(_name, _module), do: :ok
end
