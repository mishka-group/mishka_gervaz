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

  @table_entity_paths [
    [:mishka_gervaz, :table, :columns],
    [:mishka_gervaz, :table, :row_actions],
    [:mishka_gervaz, :table, :filters],
    [:mishka_gervaz, :table, :bulk_actions]
  ]

  @impl true
  def verify(dsl_state) do
    name = Verifier.get_option(dsl_state, @path, :name)
    route = Verifier.get_option(dsl_state, @path, :route)

    if is_nil(route) and not has_table_entities?(dsl_state) do
      :ok
    else
      module = Verifier.get_persisted(dsl_state, :module)
      validate_identity(name, route, module)
    end
  end

  defp has_table_entities?(dsl_state) do
    Enum.any?(@table_entity_paths, fn path ->
      dsl_state |> Verifier.get_entities(path) |> List.wrap() |> Enum.any?()
    end)
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
