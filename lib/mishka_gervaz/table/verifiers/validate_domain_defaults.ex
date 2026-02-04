defmodule MishkaGervaz.Table.Verifiers.ValidateDomainDefaults do
  @moduledoc """
  Validates the domain table configuration.

  Ensures:
  - UI adapter module exists (if specified)
  - PubSub module exists (if specified)
  - Pagination settings are valid
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    with :ok <- validate_ui_adapter(dsl_state),
         :ok <- validate_pubsub(dsl_state),
         :ok <- validate_pagination(dsl_state) do
      :ok
    end
  end

  @spec validate_ui_adapter(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_ui_adapter(dsl_state) do
    case Verifier.get_option(dsl_state, [:mishka_gervaz, :table], :ui_adapter) do
      nil ->
        :ok

      adapter when is_atom(adapter) ->
        if Code.ensure_loaded?(adapter) do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             module: Verifier.get_persisted(dsl_state, :module),
             path: [:mishka_gervaz, :table, :ui_adapter],
             message: "UI adapter module #{inspect(adapter)} is not loaded"
           )}
        end

      _ ->
        :ok
    end
  end

  @spec validate_pubsub(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_pubsub(dsl_state) do
    case Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :realtime], :pubsub) do
      nil ->
        :ok

      pubsub when is_atom(pubsub) ->
        if Code.ensure_loaded?(pubsub) do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             module: Verifier.get_persisted(dsl_state, :module),
             path: [:mishka_gervaz, :table, :realtime, :pubsub],
             message: "PubSub module #{inspect(pubsub)} is not loaded"
           )}
        end

      _ ->
        :ok
    end
  end

  @spec validate_pagination(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_pagination(dsl_state) do
    page_size =
      Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :pagination], :page_size)

    cond do
      is_nil(page_size) ->
        :ok

      is_integer(page_size) and page_size > 0 ->
        :ok

      true ->
        {:error,
         Spark.Error.DslError.exception(
           module: Verifier.get_persisted(dsl_state, :module),
           path: [:mishka_gervaz, :table, :pagination, :page_size],
           message: "page_size must be a positive integer, got: #{inspect(page_size)}"
         )}
    end
  end
end
