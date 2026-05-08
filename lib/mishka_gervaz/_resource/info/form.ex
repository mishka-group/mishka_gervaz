defmodule MishkaGervaz.Resource.Info.Form do
  @moduledoc """
  Form-specific introspection for resources using `MishkaGervaz.Resource`.

  ## Usage

      # Get full form config
      config = MishkaGervaz.Resource.Info.Form.config(MyResource)

      # Get fields
      fields = MishkaGervaz.Resource.Info.Form.fields(MyResource)

      # Get groups
      groups = MishkaGervaz.Resource.Info.Form.groups(MyResource)

      # Get uploads
      uploads = MishkaGervaz.Resource.Info.Form.uploads(MyResource)
  """

  use Spark.InfoGenerator,
    extension: MishkaGervaz.Resource,
    sections: [:mishka_gervaz]

  alias Spark.Dsl.Extension

  import MishkaGervaz.Helpers,
    only: [
      map_put_if_set: 3,
      map_get: 3,
      extract_preload_source: 1,
      get_domain_defaults: 2
    ]

  @default_submit %{
    create: nil,
    update: nil,
    cancel: nil,
    position: :bottom,
    ui: nil
  }

  @doc """
  Get the full compiled form configuration for a resource.

  Returns the pre-built configuration map merged with domain defaults.
  """
  @spec config(module()) :: map() | nil
  def config(resource) do
    config = Extension.get_persisted(resource, :mishka_gervaz_form_config)

    if config do
      merge_domain_defaults(config, get_domain_defaults(resource, :form))
    else
      config
    end
  end

  @spec merge_domain_defaults(map(), map()) :: map()
  defp merge_domain_defaults(config, domain_defaults) do
    config
    |> update_in([:source, :actor_key], &(&1 || domain_defaults[:actor_key]))
    |> update_in([:source, :master_check], &(&1 || domain_defaults[:master_check]))
    |> merge_presentation_defaults(domain_defaults)
    |> merge_actions(domain_defaults)
    |> merge_submit(domain_defaults)
    |> merge_layout_defaults(domain_defaults)
    |> resolve_default_master_check()
  end

  defp merge_actions(config, domain_defaults) do
    domain_actions = domain_defaults[:actions] || %{}

    update_in(config, [:source, :actions], fn actions ->
      actions = actions || %{}

      %{
        create: actions[:create] || domain_actions[:create],
        update: actions[:update] || domain_actions[:update],
        read: actions[:read] || domain_actions[:read]
      }
    end)
  end

  defp merge_submit(config, domain_defaults) do
    Map.put(
      config,
      :submit,
      MishkaGervaz.Form.SubmitMerger.merge(config[:submit], domain_defaults[:submit])
    )
  end

  defp merge_presentation_defaults(config, domain_defaults) do
    config
    |> update_in([:presentation, :template], &(&1 || domain_defaults[:template]))
    |> update_in([:presentation, :features], &(&1 || domain_defaults[:features]))
  end

  defp merge_layout_defaults(config, %{layout: %{responsive: domain_responsive}})
       when not is_nil(domain_responsive) do
    case config[:layout] do
      nil -> config
      layout -> put_in(config, [:layout, :responsive], layout[:responsive] || domain_responsive)
    end
  end

  defp merge_layout_defaults(config, _domain_defaults), do: config

  defp resolve_default_master_check(%{source: %{master_check: mc}} = config)
       when not is_nil(mc),
       do: config

  defp resolve_default_master_check(config) do
    put_in(config, [:source, :master_check], &MishkaGervaz.Helpers.master_user?/1)
  end

  @spec identity_get(module(), atom()) :: term()
  defp identity_get(resource, key) do
    case config(resource) do
      %{identity: %{^key => value}} -> value
      _ -> nil
    end
  end

  @doc """
  Get all fields for a resource form.
  """
  @spec fields(module()) :: [map()]
  def fields(resource) do
    case map_get(config(resource), :fields, %{}) do
      %{list: list} when is_list(list) -> list
      _ -> []
    end
  end

  @doc """
  Get a specific field by name.
  """
  @spec field(module(), atom()) :: map() | nil
  def field(resource, field_name) do
    Enum.find(fields(resource), &(&1.name == field_name))
  end

  @doc """
  Get the field order for a resource form.
  """
  @spec field_order(module()) :: [atom()]
  def field_order(resource) do
    Extension.get_persisted(resource, :mishka_gervaz_form_field_order, [])
  end

  @doc """
  Get all groups for a resource form.
  """
  @spec groups(module()) :: [map()]
  def groups(resource), do: map_get(config(resource), :groups, [])

  @doc """
  Get all uploads for a resource form.
  """
  @spec uploads(module()) :: [map()]
  def uploads(resource), do: map_get(config(resource), :uploads, [])

  @doc """
  Get the submit configuration for a resource form.
  """
  @spec submit(module()) :: map()
  def submit(resource), do: map_get(config(resource), :submit, @default_submit)

  @doc """
  Get the layout configuration for a resource form.
  """
  @spec layout(module()) :: map() | nil
  def layout(resource), do: map_get(config(resource), :layout, nil)

  @doc """
  Get all steps for a resource form.
  """
  @spec steps(module()) :: [map()]
  def steps(resource), do: map_get(layout(resource), :steps, [])

  @doc """
  Get a specific step by name.
  """
  @spec step(module(), atom()) :: map() | nil
  def step(resource, step_name) do
    Enum.find(steps(resource), &(&1.name == step_name))
  end

  @doc """
  Get the form header configuration. Returns nil when no header is declared.
  """
  @spec header(module()) :: map() | nil
  def header(resource), do: map_get(layout(resource), :header, nil)

  @doc """
  Get the form footer configuration. Returns nil when no footer is declared.
  """
  @spec footer(module()) :: map() | nil
  def footer(resource), do: map_get(layout(resource), :footer, nil)

  @doc """
  Get all notices declared in the form layout.
  """
  @spec notices(module()) :: [map()]
  def notices(resource), do: map_get(layout(resource), :notices, [])

  @doc """
  Get a specific notice by name.
  """
  @spec notice(module(), atom()) :: map() | nil
  def notice(resource, notice_name) do
    Enum.find(notices(resource), &(&1.name == notice_name))
  end

  @doc """
  Get notices targeting the given position. Position can be an atom or a
  `{:before_group, name}` / `{:after_group, name}` tuple.
  """
  @spec notices_at(module(), term()) :: [map()]
  def notices_at(resource, position) do
    Enum.filter(notices(resource), &(&1.position == position))
  end

  @doc """
  Get the navigation strategy for a resource form.

  Returns `:sequential` or `:free`.
  """
  @spec navigation(module()) :: :sequential | :free
  def navigation(resource), do: map_get(layout(resource), :navigation, :sequential)

  @doc """
  Get the persistence strategy for a resource form.

  Returns `:none`, `:ets`, or `:client_token`.
  """
  @spec persistence(module()) :: :none | :ets | :client_token
  def persistence(resource), do: map_get(layout(resource), :persistence, :none)

  @doc """
  Get the group maps for a given step name.

  Returns the intersection of the step's group references with the defined groups.
  """
  @spec step_groups(module(), atom()) :: [map()]
  def step_groups(resource, step_name) do
    case step(resource, step_name) do
      %{groups: step_group_names} when is_list(step_group_names) ->
        Enum.filter(groups(resource), &(&1.name in step_group_names))

      _ ->
        []
    end
  end

  @doc """
  Get the appropriate action for the current user type and action mode.

  For non-multi-tenant resources, returns the same (tenant) action for both
  master and tenant users.
  """
  @spec action_for(module(), :create | :update | :read, boolean()) :: atom()
  def action_for(resource, action_type, master_user?) do
    case config(resource) do
      %{source: %{actions: actions}} when is_map(actions) ->
        resolve_action_value(Map.get(actions, action_type), master_user?, action_type)

      _ ->
        action_type
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

  @doc """
  Get all hooks as a map.
  """
  @spec hooks(module()) :: map()
  def hooks(resource), do: map_get(config(resource), :hooks, %{})

  @doc """
  Get a JS hook function by name from the form config.

  Returns the function or nil.
  """
  @spec js_hook(module(), atom()) :: (... -> Phoenix.LiveView.JS.t()) | nil
  def js_hook(resource, hook_name) do
    case hooks(resource) do
      %{js: %{^hook_name => func}} when is_function(func) -> func
      _ -> nil
    end
  end

  @doc """
  Get detected preloads from field sources.
  """
  @spec detected_preloads(module()) :: [atom()]
  def detected_preloads(resource) do
    Extension.get_persisted(resource, :mishka_gervaz_form_detected_preloads, [])
  end

  @doc """
  Get all preloads needed (always + detected + master/tenant specific).
  """
  @spec all_preloads(module(), boolean()) :: [atom()]
  def all_preloads(resource, master_user?) do
    (preload_entries(resource, master_user?) ++ detected_preloads(resource))
    |> Enum.map(&extract_preload_source/1)
    |> Enum.uniq()
  end

  @doc """
  Get preload aliases for master/tenant context.

  Returns a map of `%{alias_key => source_key}` for resolving aliased preloads.
  Only includes entries where source != alias (actual aliases).

  ## Example

      # Given: master [master_tags: :tags], tenant [tenant_tags: :tags]
      preload_aliases(MyResource, true)   # => %{tags: :master_tags}
      preload_aliases(MyResource, false)  # => %{tags: :tenant_tags}
  """
  @spec preload_aliases(module(), boolean()) :: %{atom() => atom()}
  def preload_aliases(resource, master_user?) do
    resource
    |> preload_entries(master_user?)
    |> Enum.reduce(%{}, fn
      {source, alias_key}, acc when source != alias_key -> Map.put(acc, alias_key, source)
      _, acc -> acc
    end)
  end

  @spec preload_entries(module(), boolean()) :: [atom() | {atom(), atom()}]
  defp preload_entries(resource, master_user?) do
    case config(resource) do
      %{source: %{preload: preload}} when is_map(preload) ->
        specific = if master_user?, do: preload[:master] || [], else: preload[:tenant] || []
        (preload[:always] || []) ++ specific

      _ ->
        []
    end
  end

  @doc """
  Get the stream name for a resource form.
  """
  @spec stream_name(module()) :: atom() | nil
  def stream_name(resource), do: identity_get(resource, :stream_name)

  @doc """
  Get the route for a resource form.
  """
  @spec route(module()) :: String.t() | nil
  def route(resource), do: identity_get(resource, :route)

  @doc """
  Get the form identity name as a string, suitable for LiveComponent id.
  Returns nil if no form identity is configured.
  """
  @spec component_id(module()) :: String.t() | nil
  def component_id(resource) do
    case identity_get(resource, :name) do
      nil -> nil
      name -> to_string(name)
    end
  end

  @doc """
  Get the state configuration.

  Returns a map with any configured state module overrides.
  Keys can include: `:module`, `:field`, `:group`, `:step`, `:presentation`, `:access`.
  Empty map when no overrides are set.
  """
  @spec state(module()) :: map()
  def state(resource) do
    %{}
    |> map_put_if_set(:module, mishka_gervaz_form_state_module(resource))
    |> map_put_if_set(:field, mishka_gervaz_form_state_field(resource))
    |> map_put_if_set(:group, mishka_gervaz_form_state_group(resource))
    |> map_put_if_set(:step, mishka_gervaz_form_state_step(resource))
    |> map_put_if_set(:presentation, mishka_gervaz_form_state_presentation(resource))
    |> map_put_if_set(:access, mishka_gervaz_form_state_access(resource))
  end

  @doc """
  Get the events configuration.

  Returns a map with optional keys for sub-handler overrides:
  `:module`, `:sanitization`, `:validation`, `:submit`, `:step`, `:upload`,
  `:relation`, `:hooks`. Returns an empty map if no events configuration is set.
  """
  @spec events(module()) :: map()
  def events(resource), do: map_get(config(resource), :events, %{})

  @doc """
  Get the data_loader configuration.

  Returns a map with optional keys for sub-builder overrides:
  `:module`, `:record`, `:tenant`, `:relation`, `:hooks`.
  Returns an empty map if no data_loader configuration is set.
  """
  @spec data_loader(module()) :: map()
  def data_loader(resource), do: map_get(config(resource), :data_loader, %{})
end
