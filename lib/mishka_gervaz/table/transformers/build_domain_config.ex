defmodule MishkaGervaz.Table.Transformers.BuildDomainConfig do
  @moduledoc """
  Builds the domain-level configuration from the DSL state.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  alias MishkaGervaz.Table.Entities.{MenuGroup, Pagination}
  import MishkaGervaz.Table.Transformers.Helpers

  @table_path [:mishka_gervaz, :table]
  @nav_path [:mishka_gervaz, :navigation]

  @realtime_defaults %{enabled: true, pubsub: nil}
  @theme_defaults %{header_class: nil, row_class: nil, border_class: nil, extra: %{}}
  @refresh_defaults %{
    enabled: true,
    interval: 30_000,
    pause_on_interaction: true,
    show_indicator: true,
    pause_on_blur: true
  }
  @url_sync_defaults %{enabled: true, params: [:filters, :sort, :page], prefix: nil}
  @menu_group_keys [:name, :label, :icon, :position, :resources, :visible]

  @impl true
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl_state) do
    config = %{
      table: build_table(dsl_state),
      navigation: build_navigation(dsl_state)
    }

    {:ok, Transformer.persist(dsl_state, :mishka_gervaz_domain_config, config)}
  end

  @spec build_table(Spark.Dsl.t()) :: map()
  defp build_table(dsl_state) do
    %{
      ui_adapter: get_opt(dsl_state, @table_path, :ui_adapter, MishkaGervaz.UIAdapters.Tailwind),
      ui_adapter_opts: get_opt(dsl_state, @table_path, :ui_adapter_opts, []),
      actor_key: get_opt(dsl_state, @table_path, :actor_key, :current_user),
      master_check: get_opt(dsl_state, @table_path, :master_check),
      actions: build_actions(dsl_state),
      pagination: build_pagination(dsl_state),
      realtime: build_section(dsl_state, :realtime, @realtime_defaults),
      theme: build_section(dsl_state, :theme, @theme_defaults),
      refresh: build_section(dsl_state, :refresh, @refresh_defaults),
      url_sync: build_section(dsl_state, :url_sync, @url_sync_defaults)
    }
  end

  @spec build_actions(Spark.Dsl.t()) :: map()
  defp build_actions(dsl_state) do
    path = @table_path ++ [:actions]

    %{
      read: get_opt(dsl_state, path, :read, {:master_read, :tenant_read}),
      get: get_opt(dsl_state, path, :get, {:master_get, :read}),
      destroy: get_opt(dsl_state, path, :destroy, {:master_destroy, :destroy})
    }
  end

  @spec build_pagination(Spark.Dsl.t()) :: map() | nil
  defp build_pagination(dsl_state) do
    case find_entity(dsl_state, @table_path, Pagination) do
      nil ->
        nil

      pagination ->
        defaults = Pagination.defaults()

        %{
          type: default_if_nil(pagination.type, defaults.type),
          page_size: default_if_nil(pagination.page_size, defaults.page_size),
          page_size_options:
            default_if_nil(pagination.page_size_options, defaults.page_size_options),
          max_page_size: default_if_nil(pagination.max_page_size, defaults.max_page_size)
        }
    end
  end

  @spec build_section(Spark.Dsl.t(), atom(), map()) :: map() | nil
  defp build_section(dsl_state, section, defaults) do
    path = @table_path ++ [section]
    keys = Map.keys(defaults)
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    if Enum.any?(values, fn {_, v} -> v != nil end) do
      Map.merge(defaults, reject_nil_values(values))
    else
      nil
    end
  end

  @spec reject_nil_values(map()) :: map()
  defp reject_nil_values(map) do
    Map.reject(map, fn {_, v} -> is_nil(v) end)
  end

  @spec build_navigation(Spark.Dsl.t()) :: map() | nil
  defp build_navigation(dsl_state) do
    dsl_state
    |> Transformer.get_entities(@nav_path)
    |> List.wrap()
    |> Enum.filter(&match?(%MenuGroup{}, &1))
    |> Enum.map(&menu_group_to_map/1)
    |> Enum.sort_by(& &1.position)
    |> case do
      [] -> nil
      groups -> %{menu_groups: groups}
    end
  end

  @spec menu_group_to_map(MenuGroup.t()) :: map()
  defp menu_group_to_map(%MenuGroup{} = group) do
    Map.take(group, @menu_group_keys)
  end
end
