defmodule MishkaGervaz.Table.Verifiers.ValidateSource do
  @moduledoc """
  Validates the source section of MishkaGervaz DSL.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.Realtime

  @archive_path [:mishka_gervaz, :table, :source, :archive]
  @realtime_path [:mishka_gervaz, :table, :realtime]

  @archive_opts [
    :enabled,
    :restricted,
    :read_action,
    :get_action,
    :restore_action,
    :destroy_action
  ]

  @impl true
  def verify(dsl_state) do
    if is_nil(Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :identity], :route)) do
      :ok
    else
      do_verify(dsl_state)
    end
  end

  defp do_verify(dsl_state) do
    with module <- Verifier.get_persisted(dsl_state, :module),
         :ok <- validate_archive_section(dsl_state, module),
         :ok <- validate_archive_inheritance(dsl_state, module),
         :ok <- validate_realtime_prefix(dsl_state, module),
         do: :ok
  end

  @spec validate_archive_section(Spark.Dsl.t(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_archive_section(dsl_state, module) do
    @archive_opts
    |> Enum.any?(&(Verifier.get_option(dsl_state, @archive_path, &1) != nil))
    |> validate_archive(has_ash_archival?(module), module)
  end

  @spec validate_archive(boolean(), boolean(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_archive(false, _, _), do: :ok
  defp validate_archive(true, true, _), do: :ok

  defp validate_archive(true, false, module),
    do:
      dsl_error(module, @archive_path, "archive section requires AshArchival.Resource extension")

  @spec validate_archive_inheritance(Spark.Dsl.t(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_archive_inheritance(dsl_state, module) do
    cond do
      not has_ash_archival?(module) ->
        :ok

      resource_archive_defined?(dsl_state) ->
        :ok

      domain_archive_defined?(module) ->
        :ok

      true ->
        dsl_error(
          module,
          @archive_path,
          archive_missing_message()
        )
    end
  end

  defp resource_archive_defined?(dsl_state) do
    Enum.any?(@archive_opts, &(Verifier.get_option(dsl_state, @archive_path, &1) != nil))
  end

  defp domain_archive_defined?(module) do
    with {:ok, domain} <- safe_domain(module),
         %{table: %{archive: archive}} when is_map(archive) and map_size(archive) > 0 <-
           Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      true
    else
      _ -> false
    end
  rescue
    _ -> false
  end

  defp safe_domain(module) do
    case Ash.Resource.Info.domain(module) do
      nil -> :error
      domain -> {:ok, domain}
    end
  rescue
    _ -> :error
  end

  defp archive_missing_message do
    """
    AshArchival.Resource is in the resource extensions, but no archive
    configuration is defined.

    Either:

      * add an `archive do ... end` block under `mishka_gervaz > table > source`
        on the resource:

            mishka_gervaz do
              table do
                source do
                  archive do
                    read_action {:master_archived, :archived}
                    get_action {:master_get_archived, :get_archived}
                    restore_action {:master_unarchive, :unarchive}
                    destroy_action {:master_permanent_destroy, :permanent_destroy}
                  end
                end
              end
            end

      * or add a domain-level `archive do ... end` under
        `mishka_gervaz > table` so all archival resources in the domain
        inherit the same defaults.
    """
  end

  @spec validate_realtime_prefix(Spark.Dsl.t(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_realtime_prefix(dsl_state, module) do
    dsl_state
    |> Verifier.get_entities([:mishka_gervaz, :table])
    |> List.wrap()
    |> Enum.find(&match?(%Realtime{}, &1))
    |> check_realtime_prefix(module)
  end

  @spec check_realtime_prefix(MishkaGervaz.Table.Entities.Realtime.t() | nil, module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp check_realtime_prefix(nil, _), do: :ok
  defp check_realtime_prefix(%{enabled: false}, _), do: :ok

  defp check_realtime_prefix(%{prefix: p}, module) when p in [nil, ""] do
    realtime_message = """
    realtime prefix is required when enabled.

    Example:
      realtime do
        prefix "posts"
      end
    """

    dsl_error(module, @realtime_path, realtime_message)
  end

  defp check_realtime_prefix(_, _), do: :ok

  @spec has_ash_archival?(module()) :: boolean()
  defp has_ash_archival?(module) do
    AshArchival.Resource in Spark.extensions(module)
  rescue
    _ -> false
  end

  @spec dsl_error(module(), list(), String.t()) :: {:error, Spark.Error.DslError.t()}
  defp dsl_error(module, path, message) do
    {:error, Spark.Error.DslError.exception(module: module, path: path, message: message)}
  end
end
