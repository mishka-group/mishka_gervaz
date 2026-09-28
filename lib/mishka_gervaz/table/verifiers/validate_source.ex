defmodule MishkaGervaz.Table.Verifiers.ValidateSource do
  @moduledoc """
  Validates the source section of MishkaGervaz DSL.

  Every action the table names — master and tenant alike, set on the resource or inherited from the
  domain — must be an action of the resource, of the matching kind: `read` and `get` read actions,
  `destroy` a destroy action. `destroy` is checked only when a `:destroy` row action or bulk action
  uses it. When archive applies, its `read_action` and `get_action` must be read actions,
  `restore_action` an update action and `destroy_action` a destroy action.

  Each failure is a `Spark.Error.DslError`, which Spark prints as a compile warning. Compile with
  `--warnings-as-errors` to fail the build on it.

  See `MishkaGervaz.Table.Dsl.Source`,
  `MishkaGervaz.Table.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.{BulkAction, Realtime, RowAction, RowActionDropdown}
  import MishkaGervaz.Table.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]
  import MishkaGervaz.Helpers, only: [missing_actions: 4, missing_actions_message: 4]

  @actions_path [:mishka_gervaz, :table, :source, :actions]
  @archive_path [:mishka_gervaz, :table, :source, :archive]
  @realtime_path [:mishka_gervaz, :table, :realtime]
  @row_path [:mishka_gervaz, :table, :row]
  @row_actions_path [:mishka_gervaz, :table, :row_actions]
  @bulk_actions_path [:mishka_gervaz, :table, :bulk_actions]

  @base_required [:read]

  # Row-action types whose handler fetches a record by id, so they need `get`.
  @get_row_types [:destroy, :update, :unarchive, :permanent_destroy, :accordion]

  @archive_opts [
    :enabled,
    :restricted,
    :read_action,
    :get_action,
    :restore_action,
    :destroy_action
  ]

  @action_types [read: :read, get: :read, destroy: :destroy]

  @archive_types [
    read: {:read_action, :read},
    get: {:get_action, :read},
    restore: {:restore_action, :update},
    destroy: {:destroy_action, :destroy}
  ]

  @fix """
  Add each action to the resource, or name one it has under
  `mishka_gervaz > table > source > actions` (or `mishka_gervaz > table > source > archive` for
  an archive action).
  """

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
         :ok <- validate_required_actions(dsl_state, module),
         :ok <- validate_archive_section(dsl_state, module),
         :ok <- validate_archive_inheritance(dsl_state, module),
         :ok <- validate_actions_exist(dsl_state, module),
         :ok <- validate_realtime_prefix(dsl_state, module),
         do: :ok
  end

  @spec validate_required_actions(Spark.Dsl.t(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_required_actions(dsl_state, module) do
    domain_actions = domain_actions(module)

    missing =
      dsl_state
      |> required_actions()
      |> Enum.filter(fn key ->
        is_nil(Verifier.get_option(dsl_state, @actions_path, key)) and
          is_nil(Map.get(domain_actions, key))
      end)

    case missing do
      [] -> :ok
      _ -> dsl_error(module, @actions_path, missing_actions_message(missing))
    end
  end

  defp required_actions(dsl_state) do
    @base_required
    |> append_if(needs_get?(dsl_state), :get)
    |> append_if(needs_destroy?(dsl_state), :destroy)
  end

  defp append_if(list, true, item), do: list ++ [item]
  defp append_if(list, false, _item), do: list

  defp needs_get?(dsl_state) do
    Verifier.get_option(dsl_state, @row_path, :selectable) == true or
      bulk_actions(dsl_state) != [] or
      Enum.any?(row_actions(dsl_state), &(&1.type in @get_row_types))
  end

  defp needs_destroy?(dsl_state) do
    Enum.any?(row_actions(dsl_state), &(&1.type == :destroy)) or
      Enum.any?(bulk_actions(dsl_state), &(&1.type == :destroy))
  end

  # Top-level row actions plus the actions nested inside dropdowns.
  defp row_actions(dsl_state) do
    nested =
      dsl_state
      |> entities_of(@row_actions_path, RowActionDropdown)
      |> Enum.flat_map(fn dropdown -> Enum.filter(dropdown.items, &is_struct(&1, RowAction)) end)

    entities_of(dsl_state, @row_actions_path, RowAction) ++ nested
  end

  defp bulk_actions(dsl_state), do: entities_of(dsl_state, @bulk_actions_path, BulkAction)

  defp validate_actions_exist(dsl_state, module) do
    domain_actions = domain_actions(module)

    sources =
      @action_types
      |> Enum.reject(fn {key, _type} -> key == :destroy and not needs_destroy?(dsl_state) end)
      |> Enum.map(fn {key, type} ->
        set_here = Verifier.get_option(dsl_state, @actions_path, key)
        {key, set_here || Map.get(domain_actions, key), type, origin(set_here, module)}
      end)

    (sources ++ archive_sources(dsl_state, module))
    |> Enum.flat_map(fn {key, value, type, origin} ->
      dsl_state
      |> missing_actions(key, value, type)
      |> Enum.map(&Map.put(&1, :origin, origin))
    end)
    |> case do
      [] ->
        :ok

      missing ->
        dsl_error(module, @actions_path, missing_actions_message(module, "table", missing, @fix))
    end
  end

  defp archive_sources(dsl_state, module) do
    if has_ash_archival?(module) do
      resource_archive =
        @archive_opts
        |> Map.new(&{&1, Verifier.get_option(dsl_state, @archive_path, &1)})
        |> Map.reject(fn {_key, value} -> is_nil(value) end)

      domain_archive = domain_archive(module)

      resource_archive
      |> then(&if(&1 == %{}, do: nil, else: &1))
      |> MishkaGervaz.Table.ArchiveMerger.merge(domain_archive, %{}, true)
      |> archive_actions(resource_archive, domain_archive, module)
    else
      []
    end
  end

  defp archive_actions(%{actions: actions}, resource_archive, domain_archive, module) do
    Enum.map(@archive_types, fn {key, {option, type}} ->
      origin =
        cond do
          Map.has_key?(resource_archive, option) -> :resource
          Map.has_key?(domain_archive || %{}, option) -> domain_origin(module)
          true -> :default
        end

      {:"archive #{key}", Map.get(actions, key), type, origin}
    end)
  end

  defp archive_actions(_merged, _resource_archive, _domain_archive, _module), do: []

  defp domain_archive(module) do
    with {:ok, domain} <- safe_domain(module),
         %{table: %{archive: archive}} when is_map(archive) <-
           Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      archive
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp origin(nil, module), do: domain_origin(module)
  defp origin(_set_here, _module), do: :resource

  defp domain_origin(module) do
    case safe_domain(module) do
      {:ok, domain} -> {:domain, domain}
      :error -> :resource
    end
  end

  defp domain_actions(module) do
    with {:ok, domain} <- safe_domain(module),
         %{table: %{actions: actions}} when is_map(actions) <-
           Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      actions
    else
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp missing_actions_message(missing) do
    keys = Enum.map_join(missing, ", ", &inspect/1)
    reasons = Enum.map_join(missing, "\n", fn key -> "  * #{inspect(key)} — #{reason(key)}" end)

    """
    Missing required table source action(s): #{keys}

    #{reasons}

    Each must be defined either on the resource or on the domain (resource wins when
    both are set). A purely read-only table needs only `read`.

    Provide them on the resource:

        mishka_gervaz do
          table do
            source do
              actions do
                read {:master_read, :read}
                get {:master_get, :read}
                destroy {:master_destroy, :destroy}
              end
            end
          end
        end

    Or on the domain (inherited by every resource in the domain):

        mishka_gervaz do
          table do
            actions do
              read {:master_read, :read}
              get {:master_get, :read}
              destroy {:master_destroy, :destroy}
            end
          end
        end

    Each value can be a single atom (used for both master and tenant requests)
    or a tuple `{master_action, tenant_action}`.
    """
  end

  defp reason(:read), do: "every table must declare a read action"

  defp reason(:get),
    do:
      "the table has interactive rows (a row action, selection, or an expand/accordion) " <>
        "that fetch a single record by id"

  defp reason(:destroy), do: "the table has a `:destroy` row action or bulk action"

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
    |> entities_of([:mishka_gervaz, :table], Realtime)
    |> List.first()
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
end
