defmodule MishkaGervaz.Table.Web.UrlSync do
  @moduledoc """
  URL state synchronization for bookmarkable table views.

  Syncs table state (filters, sort, page, search) to URL query params,
  allowing users to bookmark or share specific table views.

  ## Configuration

  Enable URL sync in domain table config:

      mishka_gervaz do
        table do
          url_sync do
            enabled true
            params [:filters, :sort, :page]
            prefix "table"
          end
        end
      end

  ## Usage in LiveView

  In your parent LiveView, handle URL params:

      def handle_params(params, _uri, socket) do
        url_state = MishkaGervaz.Table.Web.UrlSync.decode(params, "table")

        {:noreply,
          socket
          |> assign(:url_state, url_state)}
      end

  Pass to the component:

      <.live_component
        module={MishkaGervaz.Table.Web.Live}
        id="posts-table"
        resource={MyApp.Post}
        url_state={@url_state}
      />

  ## Param Format

  - Filters: `?table_filter_status=active&table_filter_category=1`
  - Sort: `?table_sort=name:asc` or `?table_sort=inserted_at:desc`
  - Page: `?table_page=2`
  - Search: `?table_search=hello` — with `:search` in `params`, the search filter (`:search`, or
    `:q`) is written here and not again as `table_filter_search`; it is read back into the table's
    own search filter
  - Template: `?table_template=grid` — the `name/0` of the template the table shows. A URL naming
    one of the table's `switchable_templates` opens the table in it; any other name is ignored

  A parameter that holds anything else than it may, such as `?table_sort[a]=b`, reads as missing
  (`decode/3`).

  See `MishkaGervaz.Table.Web.State`,
  `MishkaGervaz.Table.Web.State.UrlSync` (the in-state sub-builder),
  `MishkaGervaz.Table.Dsl.UrlSync` (resource-level DSL section),
  `MishkaGervaz.Table.Dsl.Defaults` (domain-level defaults).
  """

  import MishkaGervaz.Helpers, only: [find_by_name: 2, positive_integer: 1, strip_tags: 1]
  import MishkaGervaz.Table.Web.State.Helpers, only: [search_filter_name: 1]

  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Table.Types.Filter

  @default_config %{
    enabled: false,
    params: [:filters, :sort, :page],
    prefix: nil
  }

  @default_max_filter_length 500
  @text_filters [Filter.Text, Filter.Select, Filter.Boolean, Filter.Number, Filter.Date]

  @type url_state :: %{
          filters: map(),
          sort: list({atom(), :asc | :desc}),
          page: pos_integer(),
          page_size: pos_integer() | nil,
          search: String.t() | nil,
          template: atom() | nil,
          path: String.t() | nil,
          path_params: map(),
          preserved_params: map(),
          query: %{String.t() => String.t()} | nil
        }

  @type decode_opts :: [
          allowed_params: list(atom()),
          allowed_filters: list(atom()),
          max_filter_length: non_neg_integer()
        ]

  @doc """
  Encode table state to URL query params.

  ## Examples

      iex> state = %{filters: %{status: "active"}, sort: [{:name, :asc}], page: 2}
      iex> UrlSync.encode(state, %{params: [:filters, :sort, :page], prefix: "t"})
      %{"t_filter_status" => "active", "t_sort" => "name:asc", "t_page" => "2"}
  """
  @spec encode(map(), map()) :: map()
  def encode(state, config \\ @default_config) do
    prefix = config[:prefix]

    %{}
    |> maybe_encode_filters(state, config, prefix)
    |> maybe_encode_sort(state, config, prefix)
    |> maybe_encode_page(state, config, prefix)
    |> maybe_encode_page_size(state, config, prefix)
    |> maybe_encode_search(state, config, prefix)
    |> maybe_encode_template(state, config, prefix)
  end

  @doc """
  Decode URL query params to table state.

  Gets all configuration from the resource's DSL (url_sync section and filters).
  Always pass the URI - the system uses it for bidirectional sync if enabled in DSL. Its query
  string is kept as `:query`, the params by name. The table applies each URL once: handed the one
  it took last again, as when the page renders it for a reason of its own, it keeps its state; its
  own write coming back is the very URL it wrote (`same_url?/2`). A `url_state` without `:query`
  is applied whenever it differs from the table's state.

  A page or page size that is not a positive whole number (`0`, `-2`, `two`, `1.5`) reads as
  missing: page 1, and the table's own page size. A page of any size is kept here; the table opens
  it only when the database can read it (`MishkaGervaz.Table.Web.State.UrlSync`).

  A sort entry whose order is neither `asc` nor `desc`, or whose field is neither one of the
  resource's nor a column of its table, is dropped here. The table then sorts only by the fields it
  sorts by itself, its sortable columns and its default sort; a URL whose sort keeps none of them
  opens the table's own sort (`MishkaGervaz.Table.Web.State.UrlSync`).

  ## What a parameter may hold

  The sort, search, page, page size and template are a text of at most `max_filter_length`
  characters. Anything else, a map, a list or a longer text, reads as missing. A null byte and bytes
  that are no UTF-8 are cut from the text. A filter's value is read by its type:

  | filter | value |
  | --- | --- |
  | `:text`, `:select`, `:boolean`, `:number`, `:date`, `:relation` | the text |
  | `:date_range` | a text `from~to`, `from~` or `~to`, as `%{from: _, to: _}` with the sides it has |
  | `:relation` with `mode :search_multi` | a text, a list for `a,b`, or a list of texts |
  | a type of your own | a text, a list for `a,b`, `%{from: _, to: _}` for `a~b`, or a list or map of texts |

  A preserved param is a text or a list of texts.

  ## Usage

      # In handle_params - always pass params and uri
      def handle_params(params, uri, socket) do
        url_state = UrlSync.decode(params, uri, MyApp.Post)
        {:noreply, assign(socket, :url_state, url_state)}
      end

      # With option overrides
      UrlSync.decode(params, uri, MyApp.Post, allowed_filters: [:status])

  ## Options (override DSL values)

  - `:allowed_params` - List of param types to decode (overrides DSL `params`)
  - `:allowed_filters` - List of allowed filter names (overrides DSL filters)
  - `:max_filter_length` - Max length of a text in the URL (overrides DSL `max_filter_length`)
  - `:prefix` - URL param prefix (overrides DSL `prefix`)

  ## Examples

      iex> params = %{"posts_filter_status" => "active", "posts_sort" => "name:asc"}
      iex> UrlSync.decode(params, "/posts", MyApp.Post)
      %{filters: %{status: "active"}, sort: [{:name, :asc}], page: 1, search: nil, template: nil, path: "/posts"}
  """
  @spec decode(map(), String.t(), module()) :: url_state() | nil
  def decode(params, uri, resource)
      when is_binary(uri) and is_atom(resource) and not is_nil(resource) do
    do_decode_for_resource(params, resource, [], uri)
  end

  @doc false
  def decode(params, prefix, opts) when is_binary(prefix) and is_list(opts) do
    allowed_params =
      Keyword.get(opts, :allowed_params, [:filters, :sort, :page, :search, :template])

    decoded = %{
      filters: opts |> Keyword.get(:allowed_filters) |> named_filters(:any),
      resource: nil,
      max: Keyword.get(opts, :max_filter_length) || @default_max_filter_length
    }

    do_decode(params, prefix, allowed_params, decoded, nil, %{})
  end

  @doc """
  `decode/3` with the resource's own `url_sync` configuration overridden.

  Every option defaults to what the resource declared, so pass only what differs:

    * `:allowed_params` — which of `:filters` `:sort` `:page` `:page_size` `:search` `:template`
      to read
    * `:allowed_filters` — the filter names that may arrive from the URL
    * `:max_filter_length` — texts longer than this are ignored
    * `:prefix` — the param prefix

  Returns `nil` when the resource has URL sync disabled, exactly as `decode/3` does.

      UrlSync.decode(params, uri, MyApp.Blog.Post, allowed_filters: [:status])
  """
  @spec decode(map(), String.t(), module(), decode_opts()) :: url_state() | nil
  def decode(params, uri, resource, opts)
      when is_binary(uri) and is_atom(resource) and not is_nil(resource) and is_list(opts) do
    do_decode_for_resource(params, resource, opts, uri)
  end

  @doc """
  Whether `url_state` was decoded from `url`: the same path and the same query params, in any
  order.

      UrlSync.same_url?(UrlSync.decode(params, "/posts?sort=name:asc", MyApp.Post), "/posts?sort=name%3Aasc")
      #=> true

  A `url_state` decoded without a URI has no `:query`, and is never the same.
  """
  @spec same_url?(url_state() | nil, String.t()) :: boolean()
  def same_url?(%{path: path, query: query}, url) when is_map(query) and is_binary(url) do
    {url_path, url_query} = split_url(url)
    path == url_path and query == url_query
  end

  def same_url?(_url_state, _url), do: false

  @spec do_decode_for_resource(map(), module(), keyword(), String.t()) :: url_state() | nil
  defp do_decode_for_resource(params, resource, opts, uri) do
    {path, query} = split_url(uri)

    url_sync_config = TableInfo.url_sync(resource)

    if url_sync_config && url_sync_config[:enabled] && is_list(url_sync_config[:params]) do
      prefix = Keyword.get(opts, :prefix, url_sync_config[:prefix])
      allowed_params = Keyword.get(opts, :allowed_params, url_sync_config[:params]) || []

      max_length =
        Keyword.get(opts, :max_filter_length, url_sync_config[:max_filter_length]) ||
          @default_max_filter_length

      filters =
        opts |> Keyword.get(:allowed_filters) |> named_filters(TableInfo.filters(resource))

      path_params =
        TableInfo.config(resource)[:identity][:route]
        |> extract_path_params(path, max_length)

      decoded = %{filters: filters, resource: resource, max: max_length}

      preserved =
        extract_preserved_params(params, prefix, url_sync_config[:preserve_params], max_length)

      params
      |> do_decode(prefix, allowed_params, decoded, path, path_params)
      |> Map.put(:preserved_params, preserved)
      |> Map.put(:query, query)
    else
      nil
    end
  end

  # The filters a URL may carry: the named ones, or all there are when none is named.
  @spec named_filters([atom()] | nil, [map()] | :any) :: [map()] | :any
  defp named_filters(names, filters) when names in [nil, []], do: filters

  defp named_filters(names, filters),
    do: Enum.map(names, &(find_by_name(filters, &1) || %{name: &1}))

  @spec do_decode(
          map(),
          String.t() | nil,
          list(atom()),
          %{filters: [map()] | :any, resource: module() | nil, max: pos_integer()},
          String.t() | nil,
          map()
        ) :: url_state()
  defp do_decode(params, prefix, allowed_params, decoded, path, path_params) do
    %{filters: filters, resource: resource, max: max} = decoded

    %{
      filters:
        decode_if_allowed(:filters, allowed_params, fn ->
          decode_filters(params, prefix, filters, max)
        end),
      sort:
        decode_if_allowed(:sort, allowed_params, fn ->
          decode_sort(params, prefix, resource, max)
        end),
      page: decode_if_allowed(:page, allowed_params, fn -> decode_page(params, prefix) end),
      page_size:
        decode_if_allowed(:page_size, allowed_params, fn -> decode_page_size(params, prefix) end),
      search:
        decode_if_allowed(:search, allowed_params, fn -> decode_search(params, prefix, max) end),
      template:
        decode_if_allowed(:template, allowed_params, fn ->
          decode_template(params, prefix, max)
        end),
      path: path,
      path_params: path_params
    }
  end

  @spec decode_if_allowed(atom(), list(atom()) | nil, (-> any())) :: any()
  defp decode_if_allowed(param_type, allowed_params, decode_fn) when is_list(allowed_params) do
    if param_type in allowed_params do
      decode_fn.()
    else
      default_for(param_type)
    end
  end

  defp decode_if_allowed(param_type, _allowed_params, _decode_fn), do: default_for(param_type)

  @spec default_for(atom()) :: map() | list() | integer() | nil
  defp default_for(:filters), do: %{}
  defp default_for(:sort), do: []
  defp default_for(:page), do: 1
  defp default_for(:page_size), do: nil
  defp default_for(:search), do: nil
  defp default_for(:template), do: nil

  @doc """
  Apply URL state to existing table state.

  The URL is the source of truth for the filters and the search it carries: the state's filters
  become the URL's filters, so a filter or search the URL no longer carries is dropped. A
  `MishkaGervaz.Table.Web.State` keeps each filter's `default` under them, as
  `MishkaGervaz.Table.Web.State.UrlSync` applies them. The sort, page and page size are taken when
  the URL carries them.
  """
  @spec apply_url_state(map(), url_state()) :: map()
  def apply_url_state(state, url_state) do
    state
    |> maybe_apply_filters(url_state)
    |> maybe_apply_sort(url_state)
    |> maybe_apply_page(url_state)
    |> maybe_apply_page_size(url_state)
    |> maybe_apply_search(url_state)
    |> maybe_apply_template(url_state)
  end

  @doc """
  Check if URL sync is enabled in config.
  """
  @spec enabled?(map()) :: boolean()
  def enabled?(config) do
    Map.get(config, :enabled, false)
  end

  @doc """
  Build URL path with encoded state params.

  Takes current path and state, returns path with query string.
  """
  @spec build_path(String.t(), map(), map()) :: String.t()
  def build_path(base_path, state, config) do
    params = encode(state, config)
    params = merge_preserved_params(params, state)

    if params == %{} do
      base_path
    else
      query = params |> Enum.flat_map(&query_pairs/1) |> URI.encode_query()
      "#{base_path}?#{query}"
    end
  end

  @doc """
  Check if url_state matches current table state.

  Used to detect if incoming url_state is from our own push_patch
  (to avoid duplicate data reload). The URL's search is read as the search filter it is applied
  as (`:search`, or `:q` on a table whose search filter is named so), and its template as the name
  of the state's template.
  """
  @spec matches_state?(url_state() | nil, map()) :: boolean()
  def matches_state?(nil, _state), do: false

  def matches_state?(url_state, state) do
    url_state = with_search_filter(url_state, state)

    Enum.all?(
      [
        {:filters, Map.get(state, :filter_values)},
        {:sort, Map.get(state, :sort_fields)},
        {:page, Map.get(state, :page)},
        {:page_size, Map.get(state, :current_page_size)},
        {:path_params, Map.get(state, :path_params) || %{}},
        {:template, template_name(Map.get(state, :template))}
      ],
      fn {key, current} -> specified_match?(url_state, key, current) end
    )
  end

  defp with_search_filter(%{search: search} = url_state, state)
       when is_binary(search) and search != "" do
    filters = Map.put(url_state[:filters] || %{}, search_filter_name(state), search)
    Map.put(url_state, :filters, filters)
  end

  defp with_search_filter(url_state, _state), do: url_state

  @spec specified_match?(url_state(), atom(), any()) :: boolean()
  defp specified_match?(url_state, key, current) do
    case url_state[key] do
      nil -> true
      value -> value == current
    end
  end

  @spec maybe_encode_filters(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_filters(params, state, config, prefix) do
    if :filters in (config[:params] || []) do
      filters = without_searched(Map.get(state, :filter_values, %{}), config)

      Enum.reduce(filters, params, fn {key, value}, acc ->
        case encode_value(value) do
          blank when blank in [nil, ""] -> acc
          text -> Map.put(acc, build_key(prefix, "filter_#{key}"), text)
        end
      end)
    else
      params
    end
  end

  @spec maybe_encode_sort(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_sort(params, state, config, prefix) do
    if :sort in (config[:params] || []) do
      sort = Map.get(state, :sort_fields, [])

      if sort != [] do
        sort_value =
          sort
          |> Enum.map(fn {field, dir} -> "#{field}:#{dir}" end)
          |> Enum.join(",")

        Map.put(params, build_key(prefix, "sort"), sort_value)
      else
        params
      end
    else
      params
    end
  end

  @spec maybe_encode_page(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_page(params, state, config, prefix) do
    if :page in (config[:params] || []) do
      page = Map.get(state, :page, 1)

      if page > 1 do
        Map.put(params, build_key(prefix, "page"), to_string(page))
      else
        params
      end
    else
      params
    end
  end

  @spec maybe_encode_page_size(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_page_size(params, state, config, prefix) do
    if :page_size in (config[:params] || []) do
      current_page_size = Map.get(state, :current_page_size)

      if current_page_size do
        Map.put(params, build_key(prefix, "page_size"), to_string(current_page_size))
      else
        params
      end
    else
      params
    end
  end

  @spec maybe_encode_search(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_search(params, state, config, prefix) do
    if :search in (config[:params] || []) do
      case searched(state.filter_values) do
        nil -> params
        key -> Map.put(params, build_key(prefix, "search"), state.filter_values[key])
      end
    else
      params
    end
  end

  # The filter the `<prefix>_search` param carries: `:search`, or `:q` when there is no search.
  defp searched(%{search: search}) when search not in [nil, ""], do: :search
  defp searched(%{q: q}) when q not in [nil, ""], do: :q
  defp searched(_filter_values), do: nil

  # The filters without the one the `<prefix>_search` param carries, when `:search` is a param, so
  # the URL holds it once.
  defp without_searched(filters, config) do
    if :search in (config[:params] || []),
      do: Map.delete(filters, searched(filters)),
      else: filters
  end

  @spec maybe_encode_template(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_template(params, state, config, prefix) do
    with true <- :template in (config[:params] || []),
         name when not is_nil(name) <- template_name(Map.get(state, :template)) do
      Map.put(params, build_key(prefix, "template"), to_string(name))
    else
      _not_synced -> params
    end
  end

  @spec template_name(term()) :: atom() | nil
  defp template_name(template) when is_atom(template) and not is_nil(template) do
    if Code.ensure_loaded?(template) and function_exported?(template, :name, 0),
      do: template.name(),
      else: template
  end

  defp template_name(_template), do: nil

  @spec decode_filters(map(), String.t() | nil, [map()] | :any, pos_integer()) :: map()
  defp decode_filters(params, prefix, filters, max) do
    filter_prefix = build_key(prefix, "filter_")

    for {key, value} <- params,
        String.starts_with?(key, filter_prefix),
        {:ok, filter} <- [key |> String.replace_prefix(filter_prefix, "") |> filter(filters)],
        {:ok, read} <- [decode_filter(value, filter, max)],
        into: %{},
        do: {filter.name, read}
  end

  @spec filter(String.t(), [map()] | :any) :: {:ok, map()} | :error
  defp filter(name, :any) do
    with {:ok, existing} <- existing_atom(name), do: {:ok, %{name: existing}}
  end

  defp filter(name, filters) do
    case Enum.find(filters, &(Atom.to_string(&1.name) == name)) do
      nil -> :error
      filter -> {:ok, filter}
    end
  end

  # A filter's value as its type takes it.
  @spec decode_filter(term(), map(), pos_integer()) :: {:ok, term()} | :error
  defp decode_filter(value, %{type_module: type}, max) when type in @text_filters,
    do: text(value, max)

  defp decode_filter(value, %{type_module: Filter.Relation, mode: :search_multi}, max)
       when is_list(value),
       do: texts(value, max)

  defp decode_filter(value, %{type_module: Filter.Relation, mode: :search_multi}, max) do
    with {:ok, text} <- text(value, max), do: {:ok, one_or_many(text)}
  end

  defp decode_filter(value, %{type_module: Filter.Relation}, max), do: text(value, max)

  defp decode_filter(value, %{type_module: Filter.DateRange}, max) do
    with {:ok, text} <- text(value, max),
         %{} = range <- decode_date_range(text) do
      {:ok, range}
    else
      _no_range -> :error
    end
  end

  defp decode_filter(value, _own_type, max) when is_list(value), do: texts(value, max)

  defp decode_filter(value, _own_type, max) when is_map(value) do
    with {:ok, pairs} <- value |> Enum.flat_map(&Tuple.to_list/1) |> texts(max) do
      {:ok, pairs |> Enum.chunk_every(2) |> Map.new(&List.to_tuple/1)}
    end
  end

  defp decode_filter(value, _own_type, max) do
    with {:ok, text} <- text(value, max), do: {:ok, decode_value(text)}
  end

  # A text within `max`, its tags taken out.
  @spec text(term(), pos_integer()) :: {:ok, String.t()} | :error
  defp text(value, max) do
    with {:ok, text} <- plain(value, max), do: {:ok, strip_tags(text)}
  end

  # A list of texts, within `max` together.
  @spec texts([term()], pos_integer()) :: {:ok, [String.t()]} | :error
  defp texts([_ | _] = values, max) do
    with true <- Enum.all?(values, &is_binary/1),
         {:ok, _whole} <- within(Enum.join(values, ","), max) do
      {:ok, Enum.map(values, &(&1 |> readable() |> strip_tags()))}
    else
      _not_texts -> :error
    end
  end

  defp texts(_none, _max), do: :error

  @spec plain(term(), pos_integer()) :: {:ok, String.t()} | :error
  defp plain(value, max) do
    with {:ok, text} <- within(value, max), do: {:ok, readable(text)}
  end

  @spec within(term(), pos_integer()) :: {:ok, String.t()} | :error
  defp within(value, max) when is_binary(value) and byte_size(value) <= max, do: {:ok, value}

  defp within(value, max) when is_binary(value) and byte_size(value) <= max * 4,
    do: if(String.length(value) <= max, do: {:ok, value}, else: :error)

  defp within(_value, _max), do: :error

  # The text without its null bytes and the bytes that are no UTF-8, which no database reads.
  @spec readable(String.t()) :: String.t()
  defp readable(text), do: text |> String.replace_invalid("") |> String.replace("\0", "")

  # Only for a name no list holds, such as that of a template a mount chose; Erlang answers it with
  # an exception alone.
  @spec existing_atom(String.t()) :: {:ok, atom()} | :error
  defp existing_atom(name) do
    {:ok, String.to_existing_atom(name)}
  rescue
    ArgumentError -> :error
  end

  @spec decode_sort(map(), String.t() | nil, module() | nil, pos_integer()) ::
          list({atom(), :asc | :desc})
  defp decode_sort(params, prefix, resource, max) do
    case params |> Map.get(build_key(prefix, "sort")) |> plain(max) do
      {:ok, text} -> text |> String.split(",") |> Enum.flat_map(&sort_entry(&1, resource))
      :error -> []
    end
  end

  @spec sort_entry(String.t(), module() | nil) :: [{atom(), :asc | :desc}]
  defp sort_entry(entry, resource) do
    with {name, order} <- sort_order(String.split(entry, ":")),
         {:ok, field} <- sort_field(name, resource) do
      [{field, order}]
    else
      _no_sort -> []
    end
  end

  defp sort_order([name]), do: {name, :asc}
  defp sort_order([name, "asc"]), do: {name, :asc}
  defp sort_order([name, "desc"]), do: {name, :desc}
  defp sort_order(_entry), do: :error

  @spec sort_field(String.t(), module() | nil) :: {:ok, atom()} | :error
  defp sort_field(name, nil), do: existing_atom(name)

  defp sort_field(name, resource) do
    case Ash.Resource.Info.field(resource, name) || table_column(name, resource) do
      %{name: field} -> {:ok, field}
      nil -> :error
    end
  end

  defp table_column(name, resource) do
    [nil | Map.keys(TableInfo.views(resource))]
    |> Enum.flat_map(&TableInfo.columns(resource, &1))
    |> Enum.find(&(Atom.to_string(&1.name) == name))
  end

  @spec decode_page(map(), String.t() | nil) :: pos_integer()
  defp decode_page(params, prefix) do
    params |> Map.get(build_key(prefix, "page")) |> positive_integer() || 1
  end

  @spec decode_page_size(map(), String.t() | nil) :: pos_integer() | nil
  defp decode_page_size(params, prefix) do
    params |> Map.get(build_key(prefix, "page_size")) |> positive_integer()
  end

  @spec decode_search(map(), String.t() | nil, pos_integer()) :: String.t() | nil
  defp decode_search(params, prefix, max) do
    case params |> Map.get(build_key(prefix, "search")) |> text(max) do
      {:ok, text} -> text
      :error -> nil
    end
  end

  @spec decode_template(map(), String.t() | nil, pos_integer()) :: atom() | nil
  defp decode_template(params, prefix, max) do
    with {:ok, text} <- params |> Map.get(build_key(prefix, "template")) |> plain(max),
         {:ok, name} <- existing_atom(text) do
      name
    else
      :error -> nil
    end
  end

  @spec maybe_apply_filters(map(), map()) :: map()
  defp maybe_apply_filters(%MishkaGervaz.Table.Web.State{} = state, url_state),
    do: MishkaGervaz.Table.Web.State.UrlSync.apply_url_filters(state, url_state)

  defp maybe_apply_filters(state, %{filters: filters}) when filters != %{} do
    %{state | filter_values: filters}
  end

  defp maybe_apply_filters(state, %{filters: filters}) when filters == %{} do
    %{state | filter_values: %{}, relation_filter_state: %{}}
  end

  defp maybe_apply_filters(state, _), do: state

  @spec maybe_apply_sort(map(), map()) :: map()
  defp maybe_apply_sort(state, %{sort: sort}) when sort != [] do
    %{state | sort_fields: sort}
  end

  defp maybe_apply_sort(state, _), do: state

  @spec maybe_apply_page(map(), map()) :: map()
  defp maybe_apply_page(state, %{page: page}) when page > 1 do
    %{state | page: page}
  end

  defp maybe_apply_page(state, _), do: state

  @spec maybe_apply_page_size(map(), map()) :: map()
  defp maybe_apply_page_size(state, %{page_size: size}) when is_integer(size) and size > 0 do
    %{state | current_page_size: size}
  end

  defp maybe_apply_page_size(state, _), do: state

  @spec maybe_apply_search(map(), map()) :: map()
  defp maybe_apply_search(state, %{search: search}) when is_binary(search) and search != "" do
    current = Map.get(state, :filter_values, %{})
    %{state | filter_values: Map.put(current, search_filter_name(state), search)}
  end

  defp maybe_apply_search(state, _), do: state

  @spec maybe_apply_template(map(), map()) :: map()
  defp maybe_apply_template(%MishkaGervaz.Table.Web.State{} = state, url_state),
    do: MishkaGervaz.Table.Web.State.UrlSync.apply_url_template(state, url_state)

  defp maybe_apply_template(state, _url_state), do: state

  @spec extract_preserved_params(
          map(),
          String.t() | nil,
          :all | list(atom()) | nil,
          non_neg_integer()
        ) ::
          map()
  defp extract_preserved_params(_params, _prefix, nil, _max_length), do: %{}

  defp extract_preserved_params(params, prefix, :all, max_length) do
    known_prefixes = known_param_prefixes(prefix)

    for {key, value} <- params,
        not Enum.any?(known_prefixes, &String.starts_with?(key, &1)),
        {:ok, kept} <- [preserved(value, max_length)],
        into: %{},
        do: {key, kept}
  end

  defp extract_preserved_params(params, _prefix, param_names, max_length)
       when is_list(param_names) do
    for name <- param_names,
        key = to_string(name),
        {:ok, value} <- [Map.fetch(params, key)],
        {:ok, kept} <- [preserved(value, max_length)],
        into: %{},
        do: {key, kept}
  end

  @spec preserved(term(), pos_integer()) :: {:ok, String.t() | [String.t()]} | :error
  defp preserved(value, max) when is_list(value), do: texts(value, max)
  defp preserved(value, max), do: text(value, max)

  @spec known_param_prefixes(String.t() | nil) :: list(String.t())
  defp known_param_prefixes(prefix) do
    suffixes = ["filter_", "sort", "page", "page_size", "search", "template"]
    Enum.map(suffixes, &build_key(prefix, &1))
  end

  @spec merge_preserved_params(map(), map()) :: map()
  defp merge_preserved_params(params, %{preserved_params: preserved})
       when is_map(preserved) and map_size(preserved) > 0 do
    Map.merge(params, preserved)
  end

  defp merge_preserved_params(params, _), do: params

  @spec query_pairs({String.t(), term()}) :: [{String.t(), term()}]
  defp query_pairs({key, values}) when is_list(values), do: Enum.map(values, &{key <> "[]", &1})
  defp query_pairs(pair), do: [pair]

  @spec build_key(String.t() | nil, String.t()) :: String.t()
  defp build_key(nil, suffix), do: suffix
  defp build_key("", suffix), do: suffix
  defp build_key(prefix, suffix), do: "#{prefix}_#{suffix}"

  @spec encode_value(any()) :: String.t() | nil
  defp encode_value(nil), do: nil
  defp encode_value(value) when is_list(value), do: Enum.join(value, ",")
  defp encode_value(value) when is_atom(value), do: to_string(value)

  defp encode_value(%{from: from, to: to}) do
    "#{encode_date_value(from)}~#{encode_date_value(to)}"
  end

  defp encode_value(%{from: from}), do: "#{encode_date_value(from)}~"
  defp encode_value(%{to: to}), do: "~#{encode_date_value(to)}"
  defp encode_value(value) when is_map(value) and not is_struct(value), do: nil
  defp encode_value(value), do: to_string(value)

  defp encode_date_value(%Date{} = date), do: Date.to_iso8601(date)
  defp encode_date_value(value) when is_binary(value), do: value
  defp encode_date_value(value), do: to_string(value)

  @spec decode_value(String.t()) :: String.t() | [String.t()] | map()
  defp decode_value(text) do
    if String.contains?(text, "~"), do: decode_date_range(text), else: one_or_many(text)
  end

  @spec one_or_many(String.t()) :: String.t() | [String.t()]
  defp one_or_many(text) do
    if String.contains?(text, ","), do: String.split(text, ","), else: text
  end

  defp decode_date_range(value) do
    case String.split(value, "~", parts: 2) do
      [from, to] when from != "" and to != "" -> %{from: from, to: to}
      [from, ""] when from != "" -> %{from: from}
      ["", to] when to != "" -> %{to: to}
      _ -> value
    end
  end

  @spec extract_path_params(String.t() | nil, String.t() | nil, non_neg_integer()) :: map()
  defp extract_path_params(nil, _path, _max_len), do: %{}
  defp extract_path_params(_pattern, nil, _max_len), do: %{}

  defp extract_path_params(route_pattern, actual_path, max_length) do
    pattern_segments = String.split(route_pattern, "/", trim: true)
    path_segments = String.split(actual_path, "/", trim: true)

    if length(path_segments) >= length(pattern_segments) do
      pattern_segments
      |> Enum.zip(path_segments)
      |> Enum.reduce(%{}, fn
        {":" <> param_name, value}, acc ->
          with {:ok, atom_name} <- existing_atom(param_name),
               {:ok, text} <- text(value, max_length) do
            Map.put(acc, atom_name, text)
          else
            _ -> acc
          end

        _, acc ->
          acc
      end)
    else
      %{}
    end
  end

  @spec split_url(String.t()) :: {String.t() | nil, %{String.t() => String.t()}}
  defp split_url(url) when is_binary(url) do
    %URI{path: path, query: query} = URI.parse(url)
    {path, URI.decode_query(query || "")}
  end
end
