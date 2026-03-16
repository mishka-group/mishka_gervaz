defmodule MishkaGervaz.Resource.Info.Table do
  @moduledoc """
  Table-specific introspection for resources using `MishkaGervaz.Resource`.

  ## Usage

      # Get full table config
      config = MishkaGervaz.Resource.Info.Table.config(MyResource)

      # Get columns
      columns = MishkaGervaz.Resource.Info.Table.columns(MyResource)

      # Get filters
      filters = MishkaGervaz.Resource.Info.Table.filters(MyResource)
  """

  use Spark.InfoGenerator,
    extension: MishkaGervaz.Resource,
    sections: [:mishka_gervaz]

  alias Spark.Dsl.Extension
  alias MishkaGervaz.Table.Entities.Pagination
  alias MishkaGervaz.Table.Behaviours.Template, as: TemplateBehaviour

  import MishkaGervaz.Helpers, only: [map_put_if_set: 3, module_to_snake: 1]

  @default_max_filter_length 500

  @doc """
  Get the full compiled table configuration for a resource.

  Returns the pre-built configuration map merged with domain defaults.
  """
  @spec config(module()) :: map() | nil
  def config(resource) do
    config = Extension.get_persisted(resource, :mishka_gervaz_config)

    if config do
      domain_defaults = get_domain_defaults(resource)

      config
      |> merge_domain_defaults(domain_defaults)
      |> apply_realtime_defaults(resource)
    else
      config
    end
  end

  @spec get_domain_defaults(module()) :: map()
  defp get_domain_defaults(resource) do
    with {:ok, domain} <- get_domain(resource),
         config when not is_nil(config) <-
           Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      config.table
    else
      _ -> %{}
    end
  end

  @spec get_domain(module()) :: {:ok, module()} | :error
  defp get_domain(resource) do
    case Ash.Resource.Info.domain(resource) do
      nil -> :error
      domain -> {:ok, domain}
    end
  end

  @spec merge_domain_defaults(map(), map()) :: map()
  defp merge_domain_defaults(config, domain_defaults) when domain_defaults == %{}, do: config

  defp merge_domain_defaults(config, domain_defaults) do
    realtime_defaults = domain_defaults[:realtime] || %{}
    pagination_defaults = domain_defaults[:pagination] || %{}
    refresh_defaults = domain_defaults[:refresh] || %{}
    url_sync_defaults = domain_defaults[:url_sync] || %{}

    config
    |> ensure_section(:realtime)
    |> merge_pagination(pagination_defaults)
    |> update_in([:realtime, :pubsub], fn v -> v || realtime_defaults[:pubsub] end)
    |> update_in([:realtime, :enabled], fn v -> v || realtime_defaults[:enabled] end)
    |> update_in([:source, :actor_key], fn v -> v || domain_defaults[:actor_key] end)
    |> update_in([:source, :master_check], fn v -> v || domain_defaults[:master_check] end)
    |> merge_optional_section(:refresh, refresh_defaults)
    |> merge_optional_section(:url_sync, url_sync_defaults)
  end

  @spec merge_pagination(map(), map()) :: map()
  defp merge_pagination(config, domain) do
    defaults = Pagination.defaults()
    current = config[:pagination] || %{}

    updated = %{
      type: current[:type] || domain[:type] || defaults.type,
      page_size: current[:page_size] || domain[:page_size] || defaults.page_size,
      page_size_options:
        current[:page_size_options] || domain[:page_size_options] || defaults.page_size_options,
      max_page_size: current[:max_page_size] || domain[:max_page_size] || defaults.max_page_size,
      ui: current[:ui] || %{}
    }

    Map.put(config, :pagination, updated)
  end

  @spec ensure_section(map(), atom()) :: map()
  defp ensure_section(config, key) do
    if is_nil(config[key]) do
      Map.put(config, key, %{})
    else
      config
    end
  end

  @spec merge_optional_section(map(), atom(), map()) :: map()
  defp merge_optional_section(config, _key, defaults) when map_size(defaults) == 0, do: config

  defp merge_optional_section(config, key, defaults) do
    case config[key] do
      nil ->
        Map.put(config, key, defaults)

      local_config when is_map(local_config) ->
        defaults
        |> Enum.reduce(local_config, fn {k, v}, acc ->
          if acc[k] == nil, do: Map.put(acc, k, v), else: acc
        end)
        |> then(&Map.put(config, key, &1))
    end
  end

  @spec apply_realtime_defaults(map(), module()) :: map()
  defp apply_realtime_defaults(config, resource) do
    case get_in(config, [:realtime, :prefix]) do
      nil ->
        default_prefix = resource_to_prefix(resource)
        update_in(config, [:realtime, :prefix], fn _ -> default_prefix end)

      _ ->
        config
    end
  end

  @spec resource_to_prefix(module()) :: String.t()
  defp resource_to_prefix(resource), do: module_to_snake(resource)

  @doc """
  Get enabled features for a resource.

  Returns a normalized list of enabled features (never `:all`).

  ## How Features Work

  - DSL default is `:all` - uses template's `features()` as the source of truth
  - `:all` → calls template's `features()` callback to get supported features
  - `[:sort, :filter]` → uses the explicit list directly

  Each template defines which features it supports via its `features()` callback.
  Setting `:all` means "use all features this template supports".

  ## Examples

      # DSL: features [:filter, :paginate]
      features(MyResource) #=> [:filter, :paginate]

      # DSL: features :all (or not set, since :all is default)
      features(MyResource) #=> [:sort, :filter, :select, ...] (from template)
  """
  @spec features(module()) :: [TemplateBehaviour.feature()]
  def features(resource) do
    config = config(resource)
    template = config[:presentation][:template] || MishkaGervaz.Table.Templates.Table
    dsl_features = config[:presentation][:features]

    case dsl_features do
      val when val in [nil, :all] -> TemplateBehaviour.normalize_features(template.features())
      list when is_list(list) -> list
    end
  end

  @doc """
  Check if a specific feature is enabled for a resource.

  ## Examples

      feature_enabled?(MyResource, :sort) #=> true
      feature_enabled?(MyResource, :export) #=> false
  """
  @spec feature_enabled?(module(), TemplateBehaviour.feature()) :: boolean()
  def feature_enabled?(resource, feature) do
    feature in features(resource)
  end

  @doc """
  Get all columns for a resource.
  """
  @spec columns(module()) :: [struct()]
  def columns(resource) do
    mishka_gervaz_table_columns(resource)
    |> Enum.filter(&is_struct(&1, MishkaGervaz.Table.Entities.Column))
  end

  @doc """
  Get the column order for a resource.
  """
  @spec column_order(module()) :: [atom()]
  def column_order(resource) do
    Extension.get_persisted(resource, :mishka_gervaz_column_order, [])
  end

  @doc """
  Get a specific column by name.
  """
  @spec column(module(), atom()) :: struct() | nil
  def column(resource, column_name) do
    Enum.find(columns(resource), &(&1.name == column_name))
  end

  @doc """
  Get all filters for a resource.
  """
  @spec filters(module()) :: [struct()]
  def filters(resource) do
    mishka_gervaz_table_filters(resource)
    |> Enum.filter(&is_struct(&1, MishkaGervaz.Table.Entities.Filter))
  end

  @doc """
  Get a specific filter by name.
  """
  @spec filter(module(), atom()) :: struct() | nil
  def filter(resource, filter_name) do
    Enum.find(filters(resource), &(&1.name == filter_name))
  end

  @doc """
  Get all row actions for a resource.
  """
  @spec row_actions(module()) :: [struct()]
  def row_actions(resource) do
    mishka_gervaz_table_row_actions(resource)
    |> Enum.filter(&is_struct(&1, MishkaGervaz.Table.Entities.RowAction))
  end

  @doc """
  Get a specific row action by name.
  """
  @spec row_action(module(), atom()) :: struct() | nil
  def row_action(resource, action_name) do
    Enum.find(row_actions(resource), &(&1.name == action_name))
  end

  @doc """
  Get all bulk actions for a resource.
  """
  @spec bulk_actions(module()) :: [struct()]
  def bulk_actions(resource) do
    mishka_gervaz_table_bulk_actions(resource)
    |> Enum.filter(&is_struct(&1, MishkaGervaz.Table.Entities.BulkAction))
  end

  @doc """
  Get the appropriate action for the current user type.

  For non-multi-tenant resources, returns the same (tenant) action for both
  master and tenant users, since there's no need for differentiation.
  """
  @spec action_for(module(), :read | :get | :destroy, boolean()) :: atom()
  def action_for(resource, action_type, master_user?) do
    case config(resource) do
      %{source: %{actions: actions}} when is_map(actions) ->
        action_value = Map.get(actions, action_type)
        resolve_action_value(action_value, master_user?, action_type)

      _ ->
        get_action_from_dsl(resource, action_type, master_user?)
    end
  end

  @spec resolve_action_value({atom(), atom()} | atom() | nil, boolean(), atom()) :: atom()
  defp resolve_action_value({master_action, tenant_action}, master_user?, _action_type) do
    if master_user?, do: master_action, else: tenant_action
  end

  defp resolve_action_value(action, _master_user?, _action_type) when is_atom(action) do
    action
  end

  defp resolve_action_value(nil, _master_user?, action_type) do
    action_type
  end

  @spec get_action_from_dsl(module(), :read | :get | :destroy, boolean()) :: atom()
  defp get_action_from_dsl(resource, action_type, master_user?) do
    {master_action, tenant_action} =
      case action_type do
        :read -> mishka_gervaz_table_source_actions_read!(resource)
        :get -> mishka_gervaz_table_source_actions_get!(resource)
        :destroy -> mishka_gervaz_table_source_actions_destroy!(resource)
      end

    if master_user?, do: master_action, else: tenant_action
  end

  @doc """
  Get the appropriate archive action for the current user type.

  Returns the archive action for `:read`, `:get`, `:restore`, or `:destroy`.
  Returns `nil` if archive is not configured for the resource.
  """
  @spec archive_action_for(module(), :read | :get | :restore | :destroy, boolean()) ::
          atom() | nil
  def archive_action_for(resource, action_type, master_user?) do
    case config(resource) do
      %{source: %{archive: %{actions: actions}}} when is_map(actions) ->
        action_value = Map.get(actions, action_type)
        resolve_archive_action_value(action_value, master_user?)

      _ ->
        nil
    end
  end

  @spec resolve_archive_action_value({atom(), atom()} | atom() | nil, boolean()) :: atom() | nil
  defp resolve_archive_action_value({master_action, tenant_action}, master_user?) do
    if master_user?, do: master_action, else: tenant_action
  end

  defp resolve_archive_action_value(action, _master_user?) when is_atom(action) do
    action
  end

  defp resolve_archive_action_value(nil, _master_user?) do
    nil
  end

  @doc """
  Check if archive is enabled for a resource.
  """
  @spec archive_enabled?(module()) :: boolean()
  def archive_enabled?(resource) do
    case config(resource) do
      %{source: %{archive: %{enabled: true}}} -> true
      _ -> false
    end
  end

  @doc """
  Get detected preloads from column sources.
  """
  @spec detected_preloads(module()) :: [atom()]
  def detected_preloads(resource) do
    Extension.get_persisted(resource, :mishka_gervaz_detected_preloads, [])
  end

  @doc """
  Get all preloads needed (always + detected + master/tenant specific).

  Preload items can be atoms or `{source, alias}` tuples. This function
  extracts just the source atoms for the actual preload query.
  """
  @spec all_preloads(module(), boolean()) :: [atom()]
  def all_preloads(resource, master_user?) do
    always = mishka_gervaz_table_source_preload_always!(resource)

    specific =
      if master_user?,
        do: mishka_gervaz_table_source_preload_master!(resource),
        else: mishka_gervaz_table_source_preload_tenant!(resource)

    (always ++ specific ++ detected_preloads(resource))
    |> Enum.map(&extract_preload_source/1)
    |> Enum.uniq()
  end

  @doc """
  Get preload aliases for master/tenant context.

  Returns a map of `%{alias_key => source_key}` for resolving aliased preloads.
  Only includes entries where source != alias (actual aliases).

  ## Example

      # Given: master [layout: :layout], tenant [tenant_layout: :layout]
      preload_aliases(MyResource, true)   # => %{}  (no aliasing for master)
      preload_aliases(MyResource, false)  # => %{layout: :tenant_layout}
  """
  @spec preload_aliases(module(), boolean()) :: %{atom() => atom()}
  def preload_aliases(resource, master_user?) do
    always = mishka_gervaz_table_source_preload_always!(resource)

    specific =
      if master_user?,
        do: mishka_gervaz_table_source_preload_master!(resource),
        else: mishka_gervaz_table_source_preload_tenant!(resource)

    (always ++ specific)
    |> Enum.reduce(%{}, fn
      {source, alias_key}, acc when source != alias_key ->
        Map.put(acc, alias_key, source)

      _, acc ->
        acc
    end)
  end

  @spec extract_preload_source(atom() | {atom(), atom()}) :: atom()
  defp extract_preload_source({source, _alias}), do: source
  defp extract_preload_source(source) when is_atom(source), do: source

  @doc """
  Get the stream name for a resource.
  """
  @spec stream_name(module()) :: atom() | nil
  def stream_name(resource) do
    case mishka_gervaz_table_identity_stream_name(resource) do
      {:ok, name} -> name
      :error -> nil
    end
  end

  @doc """
  Get the route for a resource.
  """
  @spec route(module()) :: String.t() | nil
  def route(resource) do
    case mishka_gervaz_table_identity_route(resource) do
      {:ok, route} -> route
      :error -> nil
    end
  end

  @doc """
  Get all hooks as a map.
  """
  @spec hooks(module()) :: map()
  def hooks(resource) do
    %{
      on_load: get_hook(resource, :on_load),
      before_delete: get_hook(resource, :before_delete),
      after_delete: get_hook(resource, :after_delete),
      on_realtime: get_hook(resource, :on_realtime),
      on_expand: get_hook(resource, :on_expand),
      on_filter: get_hook(resource, :on_filter),
      on_event: get_hook(resource, :on_event),
      on_select: get_hook(resource, :on_select),
      on_sort: get_hook(resource, :on_sort)
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  @spec get_hook(module(), atom()) :: term() | nil
  defp get_hook(resource, hook_name) do
    case apply(__MODULE__, :"mishka_gervaz_table_hooks_#{hook_name}", [resource]) do
      {:ok, hook} -> hook
      :error -> nil
    end
  end

  @doc """
  Get the refresh configuration.
  """
  @spec refresh(module()) :: map() | nil
  def refresh(resource) do
    %{}
    |> map_put_if_set(:enabled, mishka_gervaz_table_refresh_enabled(resource))
    |> map_put_if_set(:interval, mishka_gervaz_table_refresh_interval(resource))
    |> map_put_if_set(
      :pause_on_interaction,
      mishka_gervaz_table_refresh_pause_on_interaction(resource)
    )
    |> map_put_if_set(:show_indicator, mishka_gervaz_table_refresh_show_indicator(resource))
    |> map_put_if_set(:pause_on_blur, mishka_gervaz_table_refresh_pause_on_blur(resource))
    |> case do
      config when config == %{} -> nil
      config -> config
    end
  end

  @doc """
  Get the URL sync configuration.
  """
  @spec url_sync(module()) :: map() | nil
  def url_sync(resource) do
    %{}
    |> map_put_if_set(:enabled, mishka_gervaz_table_url_sync_enabled(resource))
    |> map_put_if_set(:mode, mishka_gervaz_table_url_sync_mode(resource))
    |> map_put_if_set(:params, mishka_gervaz_table_url_sync_params(resource))
    |> map_put_if_set(:prefix, mishka_gervaz_table_url_sync_prefix(resource))
    |> map_put_if_set(
      :max_filter_length,
      mishka_gervaz_table_url_sync_max_filter_length(resource)
    )
    |> map_put_if_set(
      :preserve_params,
      mishka_gervaz_table_url_sync_preserve_params(resource)
    )
    |> case do
      config when config == %{} ->
        nil

      config ->
        config
        |> Map.put_new(:max_filter_length, @default_max_filter_length)
        |> Map.put_new(:mode, :read_only)
    end
  end

  @doc """
  Get the state configuration.

  Returns a map with any configured state module overrides.
  Keys can include: `:module`, `:column`, `:filter`, `:action`, `:presentation`, `:url_sync`, `:access`
  """
  @spec state(module()) :: map()
  def state(resource) do
    %{}
    |> map_put_if_set(:module, mishka_gervaz_table_state_module(resource))
    |> map_put_if_set(:column, mishka_gervaz_table_state_column(resource))
    |> map_put_if_set(:filter, mishka_gervaz_table_state_filter(resource))
    |> map_put_if_set(:action, mishka_gervaz_table_state_action(resource))
    |> map_put_if_set(:presentation, mishka_gervaz_table_state_presentation(resource))
    |> map_put_if_set(:url_sync, mishka_gervaz_table_state_url_sync(resource))
    |> map_put_if_set(:access, mishka_gervaz_table_state_access(resource))
  end

  @doc """
  Get the data_loader configuration.

  Returns a map with any configured data_loader module overrides.
  Keys can include: `:module`, `:query`, `:filter_parser`, `:pagination`, `:tenant`, `:hooks`
  """
  @spec data_loader(module()) :: map()
  def data_loader(resource) do
    case Extension.get_persisted(resource, :mishka_gervaz_config) do
      %{data_loader: data_loader} when is_map(data_loader) -> data_loader
      _ -> %{}
    end
  end

  @doc """
  Get the events configuration from the resource.

  Returns a map with optional keys for sub-builder overrides:
  - `:sanitization` - Custom sanitization handler module
  - `:record` - Custom record handler module
  - `:selection` - Custom selection handler module
  - `:bulk_action` - Custom bulk action handler module
  - `:hooks` - Custom hook runner module
  - `:module` - Complete events module override

  Returns an empty map if no events configuration is set.
  """
  @spec events(module()) :: map()
  def events(resource) do
    case Extension.get_persisted(resource, :mishka_gervaz_config) do
      %{events: events} when is_map(events) -> events
      _ -> %{}
    end
  end

  @doc """
  Get the filter mode for a resource.
  """
  @spec filter_mode(module()) :: atom()
  def filter_mode(resource) do
    case config(resource) do
      %{presentation: %{filter_mode: mode}} when is_atom(mode) -> mode
      _ -> :inline
    end
  end

  @doc """
  Get all filter groups for a resource.
  """
  @spec filter_groups(module()) :: [map()]
  def filter_groups(resource) do
    case config(resource) do
      %{filter_groups: groups} when is_list(groups) -> groups
      _ -> []
    end
  end

  @doc """
  Get a specific filter group by name.
  """
  @spec filter_group(module(), atom()) :: map() | nil
  def filter_group(resource, group_name) do
    Enum.find(filter_groups(resource), &(&1.name == group_name))
  end

  @doc """
  Get the full pagination configuration for a resource.
  Returns nil when pagination is disabled or not configured.
  """
  @spec pagination(module()) :: map() | nil
  def pagination(resource) do
    case config(resource) do
      %{pagination: pagination} -> pagination
      _ -> nil
    end
  end

  @doc """
  Check if pagination is enabled for a resource.
  """
  @spec pagination_enabled?(module()) :: boolean()
  def pagination_enabled?(resource), do: pagination(resource) != nil

  @doc """
  Get the pagination type for a resource.
  """
  @spec pagination_type(module()) :: :numbered | :infinite | :load_more | nil
  def pagination_type(resource) do
    case pagination(resource) do
      %{type: type} -> type
      _ -> nil
    end
  end

  @doc """
  Get the page size for a resource.
  """
  @spec page_size(module()) :: pos_integer() | nil
  def page_size(resource) do
    case pagination(resource) do
      %{page_size: size} -> size
      _ -> nil
    end
  end

  @doc """
  Get the page size options for a resource.
  Returns nil when no options are configured (no dropdown shown).
  """
  @spec page_size_options(module()) :: [pos_integer()] | nil
  def page_size_options(resource) do
    case pagination(resource) do
      %{page_size_options: opts} -> opts
      _ -> nil
    end
  end

  @doc """
  Get the max page size for a resource.
  """
  @spec max_page_size(module()) :: pos_integer() | nil
  def max_page_size(resource) do
    case pagination(resource) do
      %{max_page_size: max} -> max
      _ -> nil
    end
  end

  @doc """
  Get the pagination UI configuration for a resource.
  """
  @spec pagination_ui(module()) :: struct()
  def pagination_ui(resource) do
    case config(resource) do
      %{pagination: %{ui: ui}} when is_struct(ui) ->
        ui

      %{pagination: %{ui: ui}} when is_map(ui) ->
        struct(MishkaGervaz.Table.Entities.Pagination.Ui, ui)

      _ ->
        struct(MishkaGervaz.Table.Entities.Pagination.Ui)
    end
  end
end
