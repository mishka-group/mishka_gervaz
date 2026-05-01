defmodule MishkaGervaz.Table.ArchiveMerger do
  @moduledoc """
  Resolves the final table `archive` configuration by merging the resource-level
  archive map (built from the DSL) with the domain-level archive defaults.

  ## Priority rules

    * Resource has no `AshArchival.Resource` extension → archive is `nil`,
      regardless of what the domain provides. Archive cannot be applied to a
      resource that does not have AshArchival in its extensions.
    * Resource has `AshArchival.Resource` and an explicit `archive` block:
      - `enabled: false` on the resource block disables archive entirely
        (used during testing — overrides the domain).
      - Otherwise the resource block wins per key; missing keys fall back to
        the domain; missing in both → built-in default for that key.
    * Resource has `AshArchival.Resource` but no `archive` block:
      - If the domain defines archive defaults, use them (inherit fully).
      - If neither side defines anything, fall back to the built-in defaults
        (the canonical `{:master_*, :*}` action set). This preserves existing
        behaviour for resources that just opt in via `AshArchival`.

  ## Action value semantics

    * Atom value (e.g. `:archived`) — used for both master and tenant requests.
    * Tuple value `{master, tenant}` — `master` for users without `site_id`,
      `tenant` for users scoped to a `site_id`. Enforcement lives inside the
      Ash actions themselves; this module only routes which atom to call.
  """

  @action_keys [:read, :get, :restore, :destroy]

  @builtin_actions %{
    read: {:master_archived, :archived},
    get: {:master_get_archived, :get_archived},
    restore: {:master_unarchive, :unarchive},
    destroy: {:master_permanent_destroy, :permanent_destroy}
  }

  @resource_to_action %{
    read_action: :read,
    get_action: :get,
    restore_action: :restore,
    destroy_action: :destroy
  }

  @doc """
  Returns the final archive map, or `nil` when archive does not apply.

  - `resource_archive` is the raw per-resource archive map (or `nil` if no
    `archive do` block is present).
  - `domain_archive` is the domain-level archive defaults map (or `nil`).
  - `multitenancy` is the resource multitenancy info; used to collapse
    master/tenant tuples to a single atom for non-multitenant resources.
  - `has_archival?` is whether the resource has `AshArchival.Resource` in its
    extensions.
  """
  @spec merge(map() | nil, map() | nil, map(), boolean()) :: map() | nil
  def merge(_resource_archive, _domain_archive, _multitenancy, false), do: nil

  def merge(%{enabled: false}, _domain_archive, _multitenancy, true), do: nil

  def merge(resource_archive, domain_archive, multitenancy, true) do
    resource_archive = resource_archive || %{}
    domain_archive = domain_archive || %{}

    %{
      enabled: true,
      restricted: resolve_flag(resource_archive[:restricted], domain_archive[:restricted], false),
      visible: resolve_flag(resource_archive[:visible], domain_archive[:visible], true),
      actions: build_actions(resource_archive, domain_archive, multitenancy)
    }
  end

  defp build_actions(resource_archive, domain_archive, multitenancy) do
    Map.new(@action_keys, fn action_key ->
      resource_key = resource_key_for(action_key)
      resource_value = Map.get(resource_archive, resource_key)
      domain_value = Map.get(domain_archive, resource_key)
      builtin_value = Map.fetch!(@builtin_actions, action_key)

      raw = resource_value || domain_value || builtin_value
      {action_key, resolve_action(raw, multitenancy)}
    end)
  end

  defp resource_key_for(action_key) do
    Enum.find_value(@resource_to_action, fn {k, v} -> if v == action_key, do: k end)
  end

  defp resolve_flag(nil, nil, default), do: default
  defp resolve_flag(nil, domain_value, _default), do: domain_value
  defp resolve_flag(resource_value, _domain_value, _default), do: resource_value

  defp resolve_action({_master, _tenant} = tuple, _multitenancy), do: tuple
  defp resolve_action(action, _multitenancy) when is_atom(action), do: action
end
