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

  @doc """
  Get the full compiled form configuration for a resource.

  Returns the pre-built configuration map merged with domain defaults.
  """
  @spec config(module()) :: map() | nil
  def config(resource) do
    config = Extension.get_persisted(resource, :mishka_gervaz_form_config)

    if config do
      domain_defaults = get_domain_defaults(resource)
      merge_domain_defaults(config, domain_defaults)
    else
      config
    end
  end

  @spec get_domain_defaults(module()) :: map()
  defp get_domain_defaults(resource) do
    with {:ok, domain} <- get_domain(resource),
         config when not is_nil(config) <-
           Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      Map.get(config, :form, %{})
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
  defp merge_domain_defaults(config, domain_defaults) when domain_defaults == %{} do
    resolve_default_master_check(config)
  end

  defp merge_domain_defaults(config, domain_defaults) do
    config
    |> update_in([:source, :actor_key], fn v -> v || domain_defaults[:actor_key] end)
    |> update_in([:source, :master_check], fn v -> v || domain_defaults[:master_check] end)
    |> resolve_default_master_check()
  end

  defp resolve_default_master_check(%{source: %{master_check: mc}} = config)
       when not is_nil(mc),
       do: config

  defp resolve_default_master_check(config) do
    update_in(config, [:source, :master_check], fn _ ->
      fn user -> MishkaGervaz.Defaults.default_master_check(user) end
    end)
  end

  @doc """
  Get all fields for a resource form.
  """
  @spec fields(module()) :: [map()]
  def fields(resource) do
    case config(resource) do
      %{fields: %{list: list}} when is_list(list) -> list
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
  def groups(resource) do
    case config(resource) do
      %{groups: groups} when is_list(groups) -> groups
      _ -> []
    end
  end

  @doc """
  Get all uploads for a resource form.
  """
  @spec uploads(module()) :: [map()]
  def uploads(resource) do
    case config(resource) do
      %{uploads: uploads} when is_list(uploads) -> uploads
      _ -> []
    end
  end

  @doc """
  Get the submit configuration for a resource form.
  """
  @spec submit(module()) :: map()
  def submit(resource) do
    case config(resource) do
      %{submit: submit} when is_map(submit) ->
        submit

      _ ->
        %{
          create_label: "Create",
          update_label: "Update",
          cancel_label: "Cancel",
          show_cancel: true,
          position: :bottom,
          ui: nil
        }
    end
  end

  @doc """
  Get the layout configuration for a resource form.
  """
  @spec layout(module()) :: map() | nil
  def layout(resource) do
    case config(resource) do
      %{layout: layout} when is_map(layout) -> layout
      _ -> nil
    end
  end

  @doc """
  Get all steps for a resource form.
  """
  @spec steps(module()) :: [map()]
  def steps(resource) do
    case layout(resource) do
      %{steps: steps} when is_list(steps) -> steps
      _ -> []
    end
  end

  @doc """
  Get a specific step by name.
  """
  @spec step(module(), atom()) :: map() | nil
  def step(resource, step_name) do
    Enum.find(steps(resource), &(&1.name == step_name))
  end

  @doc """
  Get the navigation strategy for a resource form.

  Returns `:sequential` or `:free`.
  """
  @spec navigation(module()) :: :sequential | :free
  def navigation(resource) do
    case layout(resource) do
      %{navigation: nav} -> nav
      _ -> :sequential
    end
  end

  @doc """
  Get the persistence strategy for a resource form.

  Returns `:none`, `:ets`, or `:client_token`.
  """
  @spec persistence(module()) :: :none | :ets | :client_token
  def persistence(resource) do
    case layout(resource) do
      %{persistence: p} -> p
      _ -> :none
    end
  end

  @doc """
  Get the group maps for a given step name.

  Returns the intersection of the step's group references with the defined groups.
  """
  @spec step_groups(module(), atom()) :: [map()]
  def step_groups(resource, step_name) do
    case step(resource, step_name) do
      %{groups: step_group_names} when is_list(step_group_names) ->
        all_groups = groups(resource)
        Enum.filter(all_groups, &(&1.name in step_group_names))

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
        action_value = Map.get(actions, action_type)
        resolve_action_value(action_value, master_user?, action_type)

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
  def hooks(resource) do
    case config(resource) do
      %{hooks: hooks} when is_map(hooks) -> hooks
      _ -> %{}
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
    case config(resource) do
      %{source: %{preload: preload}} when is_map(preload) ->
        always = preload[:always] || []

        specific =
          if master_user?,
            do: preload[:master] || [],
            else: preload[:tenant] || []

        (always ++ specific ++ detected_preloads(resource))
        |> Enum.map(&extract_preload_source/1)
        |> Enum.uniq()

      _ ->
        detected_preloads(resource)
    end
  end

  @spec extract_preload_source(atom() | {atom(), atom()}) :: atom()
  defp extract_preload_source({source, _alias}), do: source
  defp extract_preload_source(source) when is_atom(source), do: source

  @doc """
  Get the stream name for a resource form.
  """
  @spec stream_name(module()) :: atom() | nil
  def stream_name(resource) do
    case config(resource) do
      %{identity: %{stream_name: name}} -> name
      _ -> nil
    end
  end

  @doc """
  Get the route for a resource form.
  """
  @spec route(module()) :: String.t() | nil
  def route(resource) do
    case config(resource) do
      %{identity: %{route: route}} -> route
      _ -> nil
    end
  end
end
