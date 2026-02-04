defmodule MishkaGervaz.Table.Verifiers.ValidateIdentity do
  @moduledoc """
  Validates the identity section of MishkaGervaz DSL.

  Ensures:
  - `identity` section is present
  - `identity.name` is present
  - `identity.route` is present
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  @path [:mishka_gervaz, :table, :identity]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    name = Verifier.get_option(dsl_state, @path, :name)
    route = Verifier.get_option(dsl_state, @path, :route)

    validate_identity(name, route, module)
  end

  @spec validate_identity(atom() | nil, String.t() | nil, module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_identity(nil, nil, module) do
    {:error,
     Spark.Error.DslError.exception(
       module: module,
       path: @path,
       message:
         "identity section is required. Add: identity do name :my_table, route \"/admin/path\" end"
     )}
  end

  defp validate_identity(nil, _route, module) do
    {:error,
     Spark.Error.DslError.exception(
       module: module,
       path: @path ++ [:name],
       message: "identity.name is required"
     )}
  end

  defp validate_identity(_name, nil, module) do
    {:error,
     Spark.Error.DslError.exception(
       module: module,
       path: @path ++ [:route],
       message: "identity.route is required"
     )}
  end

  defp validate_identity(_name, _route, _module), do: :ok
end
