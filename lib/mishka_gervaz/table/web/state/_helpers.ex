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

  @max_offset 9_223_372_036_854_775_807

  @doc """
  Resolves the labels for one relation filter's currently selected ids and stores them under
  the filter's name.

  Returns `acc` unchanged when the filter has no selection, which is what makes it safe to
  fold over every filter.

      Enum.reduce(state.static.filters, %{}, &StateHelpers.hydrate_filter(&1, &2, state))
  """
  @spec hydrate_filter(map(), map(), State.t()) :: map()
  def hydrate_filter(filter, acc, state) do
    case extract_selected_ids(state.filter_values, filter.name) do
      [] -> acc
      ids -> resolve_and_store_labels(acc, filter, ids, state)
    end
  end

  @doc """
  The selected ids for one filter, as strings, with blanks removed.

  Accepts a single value or a list, so a `:search` and a `:search_multi` filter read the same.

      iex> extract_selected_ids(%{site_id: ["a", "", nil]}, :site_id)
      ["a"]
  """
  @spec extract_selected_ids(map(), atom()) :: list(String.t())
  def extract_selected_ids(filter_values, filter_name) do
    filter_values
    |> Map.get(filter_name)
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 in ["", "nil"]))
  end

  @doc """
  Asks the resource's relation loader for the records behind `selected_ids` and writes them
  into `acc` as that filter's `:selected_options`.

  The entry is shaped like a loaded page with an empty option list — the dropdown fills the
  options itself on first open; only the labels of what is already selected are needed here.
  """
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

  @doc """
  The relation loader a resource uses — its `data_loader do relation … end` override, or
  `MishkaGervaz.Table.Web.DataLoader.RelationLoader.Default`.

      loader = resolve_relation_loader(MyApp.Blog.Post)
      loader.resolve_selected(filter_map, state, ["1", "2"])
  """
  @spec resolve_relation_loader(module()) :: module()
  def resolve_relation_loader(resource) do
    dsl_config = Info.data_loader(resource)
    Map.get(dsl_config || %{}, :relation, RelationLoader.Default)
  end

  @doc """
  The configured page size, or `nil` when pagination is off.
  """
  @spec get_page_size(map()) :: pos_integer() | nil
  def get_page_size(%{pagination: %{page_size: page_size}}), do: page_size
  def get_page_size(_), do: nil

  @doc """
  The page-size choices offered in the UI, or `nil` when no dropdown should be drawn.
  """
  @spec get_page_size_options(map()) :: [pos_integer()] | nil
  def get_page_size_options(%{pagination: %{page_size_options: opts}}), do: opts
  def get_page_size_options(_), do: nil

  @doc """
  The ceiling a page size is clamped to — the guard against an oversized `?t_page_size=` in
  the URL.
  """
  @spec get_max_page_size(map()) :: pos_integer() | nil
  def get_max_page_size(%{pagination: %{max_page_size: max}}), do: max
  def get_max_page_size(_), do: nil

  @doc """
  The page the table opens for `page`: `page` itself when the database can read its offset, and
  page 1 when it cannot.

  The offset is `(page - 1)` times the page size the table reads with, its `current_page_size` or
  else the configured one. The database can read it when it fits a signed 64-bit integer, the range
  Postgres takes for `OFFSET`, so a table of 20 rows a page opens any page up to
  461,168,601,842,738,791. A table without a page size reads no offset and keeps any page. Both the
  page from the URL and the page of a `go_to_page` event pass through it.
  """
  @spec readable_page(map(), integer()) :: integer()
  def readable_page(state, page),
    do: readable_at(page, state.current_page_size || state.static.page_size)

  @spec readable_at(integer(), pos_integer() | nil) :: integer()
  defp readable_at(page, page_size)
       when is_integer(page_size) and (page - 1) * page_size > @max_offset,
       do: 1

  defp readable_at(page, _page_size), do: page

  @doc """
  The table's `layout do header … end` map, or `nil` when the resource declares none.
  """
  @spec get_layout_header(map()) :: map() | nil
  def get_layout_header(%{layout: %{header: header}}) when is_map(header), do: header
  def get_layout_header(_), do: nil

  @doc """
  The table's `layout do footer … end` map, or `nil` when the resource declares none.
  """
  @spec get_layout_footer(map()) :: map() | nil
  def get_layout_footer(%{layout: %{footer: footer}}) when is_map(footer), do: footer
  def get_layout_footer(_), do: nil

  @doc """
  Every `layout do notice … end` declared on the resource, in declaration order.
  """
  @spec get_layout_notices(map()) :: list(map())
  def get_layout_notices(%{layout: %{notices: notices}}) when is_list(notices), do: notices
  def get_layout_notices(_), do: []

  @doc """
  The feature list this table runs with.

  An explicit `features [...]` is taken as given. `:all` (the default) means the union of what
  the current template and every switchable template support, so switching views never asks
  for a feature the new template cannot draw. `:paginate` is dropped when the resource has no
  pagination configured.

      iex> get_features(%{presentation: %{features: [:sort, :filter]}}, MyTemplate)
      [:sort, :filter]
  """
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

  @doc """
  The `filter_groups` declared on the resource, or `[]`.
  """
  @spec get_filter_groups(map()) :: list(map())
  def get_filter_groups(%{filter_groups: groups}) when is_list(groups), do: groups
  def get_filter_groups(_), do: []

  @doc """
  Where the filter bar renders — `:inline` (the default), `:sidebar`, `:modal` or `:drawer`.
  """
  @spec get_filter_mode(map()) :: atom()
  def get_filter_mode(%{presentation: %{filter_mode: mode}}) when is_atom(mode), do: mode
  def get_filter_mode(_), do: :inline

  @doc """
  The pagination labels as a `MishkaGervaz.Table.Entities.Pagination.Ui` struct.

  Always a struct: a resource that configured nothing gets one with the defaults, so a
  template can read `ui.load_more_label` without checking for `nil` first.
  """
  @spec get_pagination_ui(map()) :: struct()
  def get_pagination_ui(%{pagination: %{ui: ui}}) when is_struct(ui), do: ui

  def get_pagination_ui(%{pagination: %{ui: ui}}) when is_map(ui) do
    struct(MishkaGervaz.Table.Entities.Pagination.Ui, ui)
  end

  def get_pagination_ui(_), do: struct(MishkaGervaz.Table.Entities.Pagination.Ui)

  @doc """
  The names of the columns declared `sortable true`.

      iex> get_sortable_columns([%{name: :title, sortable: true}, %{name: :body, sortable: false}])
      [:title]
  """
  @spec get_sortable_columns(list(map())) :: list(atom())
  def get_sortable_columns(columns) do
    columns
    |> Enum.filter(& &1.sortable)
    |> Enum.map(& &1.name)
  end

  @doc """
  Maps each sortable column to the database fields it sorts by.

  A column falls back to its own name unless it declared `sort_field`, which is what lets a
  `static true` column sort by something it does not display.

      iex> build_sort_field_map([%{name: :site_datetime, sortable: true, sort_field: [:inserted_at]}])
      %{site_datetime: [:inserted_at]}
  """
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

  @doc """
  Whether this reader may see the archive toggle.

  `false` unless the resource enables archive; an `archive do restricted true end` narrows it
  further to master users only.
  """
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

  @doc """
  The archive block's `visible` flag, defaulting to `true` when it is not a plain boolean —
  a function predicate is evaluated later, against live state.
  """
  @spec get_archive_visible(map()) :: boolean()
  def get_archive_visible(config) do
    case config do
      %{source: %{archive: %{visible: visible}}} when is_boolean(visible) -> visible
      _ -> true
    end
  end

  @doc """
  The stream name derived from a resource module when `identity do stream_name … end` is
  omitted.

      iex> generate_stream_name(MyApp.Blog.Post)
      :post_stream
  """
  @spec generate_stream_name(module()) :: atom()
  def generate_stream_name(resource) do
    resource |> module_to_snake("_stream") |> String.to_atom()
  end

  @doc """
  The sort a table opens with.

  The resource's `default_sort` when it declared a non-empty list; otherwise newest-first if
  there is a sortable `:inserted_at` column; otherwise no sort at all.

      iex> get_default_sort(%{columns: %{default_sort: [featured: :desc]}}, [])
      [featured: :desc]
  """
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

  @doc """
  The part of `sort` the table can sort by, in its order: each `{field, order}` whose field a
  sortable column sorts by (its `sort_field`, or its own name) or the table's default sort names.

  A field of no column, or of a column that is not sortable, is left out, so a sort from the URL
  never sends the read a field the resource cannot sort by or the table does not offer. On a table
  whose only sortable column is `:display_name`:

      readable_sort(state, display_name: :desc, name: :desc)
      #=> [display_name: :desc]
  """
  @spec readable_sort(map(), [{atom(), :asc | :desc}]) :: [{atom(), :asc | :desc}]
  def readable_sort(%{static: static}, sort) when is_list(sort) do
    sortable = sortable_fields(static)
    for {field, order} <- sort, MapSet.member?(sortable, field), do: {field, order}
  end

  defp sortable_fields(static) do
    defaults = for entry <- get_default_sort(static.config, static.columns), do: sort_name(entry)
    columns = (static.sort_field_map || %{}) |> Map.values() |> List.flatten()

    MapSet.new(defaults ++ columns)
  end

  defp sort_name({field, _order}), do: field
  defp sort_name(field), do: field

  @doc """
  The URL-sync module for a resource — its `state do url_sync … end` override, or the default
  passed in.
  """
  @spec resolve_url_sync(module() | nil, module()) :: module()
  def resolve_url_sync(nil, default_url_sync), do: default_url_sync

  def resolve_url_sync(resource, default_url_sync) do
    dsl_state = Info.state(resource)
    Map.get(dsl_state, :url_sync, default_url_sync)
  end

  @doc """
  The access module for a resource — its `state do access … end` override, or the default
  passed in.
  """
  @spec resolve_access(module() | nil, module()) :: module()
  def resolve_access(nil, default_access), do: default_access

  def resolve_access(resource, default_access) do
    dsl_state = Info.state(resource)
    Map.get(dsl_state, :access, default_access)
  end
end
