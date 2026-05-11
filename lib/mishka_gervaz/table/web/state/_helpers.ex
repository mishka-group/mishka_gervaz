defmodule MishkaGervaz.Table.Web.State.Helpers do
  @moduledoc """
  Helper functions for `MishkaGervaz.Table.Web.State`.

  Extracted from the `__using__` macro so user overrides can reuse the
  same primitives the default state implementation uses.

  ## Example

      defmodule MyApp.Table.State do
        use MishkaGervaz.Table.Web.State
        alias MishkaGervaz.Table.Web.State.Helpers, as: StateHelpers

        def hydrate_relation_filter_labels(state) do
          StateHelpers.hydrate_filter(filter, acc, state)
        end
      end

  See `MishkaGervaz.Table.Web.State`,
  `MishkaGervaz.Table.Web.State.ColumnBuilder`,
  `MishkaGervaz.Table.Web.State.FilterBuilder`,
  `MishkaGervaz.Table.Web.State.ActionBuilder`,
  `MishkaGervaz.Table.Web.State.Presentation`,
  `MishkaGervaz.Table.Web.State.UrlSync`,
  `MishkaGervaz.Table.Web.State.Access`.
  """

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.DataLoader.RelationLoader
  alias MishkaGervaz.Table.Behaviours.Template, as: TemplateBehaviour
  alias MishkaGervaz.Resource.Info.Table, as: Info

  import MishkaGervaz.Helpers, only: [module_to_snake: 2]

  @spec hydrate_filter(map(), map(), State.t()) :: map()
  def hydrate_filter(filter, acc, state) do
    case extract_selected_ids(state.filter_values, filter.name) do
      [] -> acc
      ids -> resolve_and_store_labels(acc, filter, ids, state)
    end
  end

  @spec extract_selected_ids(map(), atom()) :: list(String.t())
  def extract_selected_ids(filter_values, filter_name) do
    filter_values
    |> Map.get(filter_name)
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 in ["", "nil"]))
  end

  @spec resolve_and_store_labels(map(), map(), list(String.t()), State.t()) :: map()
  def resolve_and_store_labels(acc, filter, selected_ids, state) do
    filter_map = if is_struct(filter), do: Map.from_struct(filter), else: filter
    loader = resolve_relation_loader(state.static.resource)

    case loader.resolve_selected(filter_map, state, selected_ids) do
      {:ok, options} when is_list(options) ->
        Map.put(acc, filter.name, %{
          options: [],
          has_more?: false,
          page: 1,
          selected_options: options
        })

      _ ->
        acc
    end
  end

  @spec resolve_relation_loader(module()) :: module()
  def resolve_relation_loader(resource) do
    dsl_config = Info.data_loader(resource)
    Map.get(dsl_config || %{}, :relation, RelationLoader.Default)
  end

  @spec get_page_size(map()) :: pos_integer() | nil
  def get_page_size(%{pagination: %{page_size: page_size}}), do: page_size
  def get_page_size(_), do: nil

  @spec get_page_size_options(map()) :: [pos_integer()] | nil
  def get_page_size_options(%{pagination: %{page_size_options: opts}}), do: opts
  def get_page_size_options(_), do: nil

  @spec get_max_page_size(map()) :: pos_integer() | nil
  def get_max_page_size(%{pagination: %{max_page_size: max}}), do: max
  def get_max_page_size(_), do: nil

  @spec get_layout_header(map()) :: map() | nil
  def get_layout_header(%{layout: %{header: header}}) when is_map(header), do: header
  def get_layout_header(_), do: nil

  @spec get_layout_footer(map()) :: map() | nil
  def get_layout_footer(%{layout: %{footer: footer}}) when is_map(footer), do: footer
  def get_layout_footer(_), do: nil

  @spec get_layout_notices(map()) :: list(map())
  def get_layout_notices(%{layout: %{notices: notices}}) when is_list(notices), do: notices
  def get_layout_notices(_), do: []

  @spec get_features(map(), module()) :: list(atom())
  def get_features(config, template) do
    features =
      case get_in(config, [:presentation, :features]) do
        val when val in [nil, :all] ->
          switchable = get_in(config, [:presentation, :switchable_templates]) || []
          all_templates = Enum.uniq([template | switchable])

          all_templates
          |> Enum.flat_map(&TemplateBehaviour.normalize_features(&1.features()))
          |> Enum.uniq()

        list when is_list(list) ->
          list
      end

    if is_nil(config[:pagination]) do
      Enum.reject(features, &(&1 == :paginate))
    else
      features
    end
  end

  @spec get_filter_groups(map()) :: list(map())
  def get_filter_groups(%{filter_groups: groups}) when is_list(groups), do: groups
  def get_filter_groups(_), do: []

  @spec get_filter_mode(map()) :: atom()
  def get_filter_mode(%{presentation: %{filter_mode: mode}}) when is_atom(mode), do: mode
  def get_filter_mode(_), do: :inline

  @spec get_pagination_ui(map()) :: struct()
  def get_pagination_ui(%{pagination: %{ui: ui}}) when is_struct(ui), do: ui

  def get_pagination_ui(%{pagination: %{ui: ui}}) when is_map(ui) do
    struct(MishkaGervaz.Table.Entities.Pagination.Ui, ui)
  end

  def get_pagination_ui(_), do: struct(MishkaGervaz.Table.Entities.Pagination.Ui)

  @spec get_sortable_columns(list(map())) :: list(atom())
  def get_sortable_columns(columns) do
    columns
    |> Enum.filter(& &1.sortable)
    |> Enum.map(& &1.name)
  end

  @spec build_sort_field_map(list(map())) :: %{atom() => [atom()]}
  def build_sort_field_map(columns) do
    columns
    |> Enum.filter(& &1.sortable)
    |> Map.new(fn col ->
      sort_field = Map.get(col, :sort_field, [])
      fields = if sort_field not in [nil, []], do: sort_field, else: [col.name]

      {col.name, fields}
    end)
  end

  @spec get_supports_archive(map(), boolean()) :: boolean()
  def get_supports_archive(config, master_user?) do
    case config do
      %{source: %{archive: %{enabled: true, restricted: true}}} ->
        master_user? and get_archive_visible(config)

      %{source: %{archive: %{enabled: true}}} ->
        get_archive_visible(config)

      _ ->
        false
    end
  end

  @spec get_archive_visible(map()) :: boolean()
  def get_archive_visible(config) do
    case config do
      %{source: %{archive: %{visible: visible}}} when is_boolean(visible) -> visible
      _ -> true
    end
  end

  @spec generate_stream_name(module()) :: atom()
  def generate_stream_name(resource) do
    resource |> module_to_snake("_stream") |> String.to_atom()
  end

  @spec get_default_sort(map(), [map()]) :: [{atom(), :asc | :desc}]
  def get_default_sort(config, columns) do
    columns_config = Map.get(config, :columns, %{})
    default_sort = Map.get(columns_config, :default_sort)

    cond do
      is_list(default_sort) and default_sort != [] ->
        default_sort

      Enum.any?(columns, &(&1.name == :inserted_at and &1.sortable)) ->
        [{:inserted_at, :desc}]

      true ->
        []
    end
  end

  @spec resolve_url_sync(module() | nil, module()) :: module()
  def resolve_url_sync(nil, default_url_sync), do: default_url_sync

  def resolve_url_sync(resource, default_url_sync) do
    dsl_state = Info.state(resource)
    Map.get(dsl_state, :url_sync, default_url_sync)
  end

  @spec resolve_access(module() | nil, module()) :: module()
  def resolve_access(nil, default_access), do: default_access

  def resolve_access(resource, default_access) do
    dsl_state = Info.state(resource)
    Map.get(dsl_state, :access, default_access)
  end
end
