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
  - Search: `?table_search=hello`
  - Template: `?table_template=grid`
  """

  @default_config %{
    enabled: false,
    params: [:filters, :sort, :page],
    prefix: nil
  }

  @default_max_filter_length 500

  @type url_state :: %{
          filters: map(),
          sort: list({atom(), :asc | :desc}),
          page: integer(),
          page_size: pos_integer() | nil,
          search: String.t() | nil,
          template: atom() | nil,
          path: String.t() | nil,
          path_params: map(),
          preserved_params: map()
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
  Always pass the URI - the system uses it for bidirectional sync if enabled in DSL.

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
  - `:max_filter_length` - Max length for filter values (overrides DSL `max_filter_length`)
  - `:prefix` - URL param prefix (overrides DSL `prefix`)

  ## Examples

      iex> params = %{"posts_filter_status" => "active", "posts_sort" => "name:asc"}
      iex> UrlSync.decode(params, "/posts", MyApp.Post)
      %{filters: %{status: "active"}, sort: [{:name, :asc}], page: 1, search: nil, template: nil, path: "/posts"}
  """
  @spec decode(map(), String.t(), module()) :: url_state() | nil
  def decode(params, uri, resource)
      when is_binary(uri) and is_atom(resource) and not is_nil(resource) do
    path = extract_path(uri)
    do_decode_for_resource(params, resource, [], path)
  end

  @doc false
  def decode(params, prefix, opts) when is_binary(prefix) and is_list(opts) do
    allowed_params =
      Keyword.get(opts, :allowed_params, [:filters, :sort, :page, :search, :template])

    allowed_filters = Keyword.get(opts, :allowed_filters, nil)
    max_filter_length = Keyword.get(opts, :max_filter_length, @default_max_filter_length)

    do_decode(params, prefix, allowed_params, allowed_filters, max_filter_length, nil, %{})
  end

  @spec decode(map(), String.t(), module(), decode_opts()) :: url_state() | nil
  def decode(params, uri, resource, opts)
      when is_binary(uri) and is_atom(resource) and not is_nil(resource) and is_list(opts) do
    path = extract_path(uri)
    do_decode_for_resource(params, resource, opts, path)
  end

  @spec do_decode_for_resource(map(), module(), keyword(), String.t() | nil) :: url_state() | nil
  defp do_decode_for_resource(params, resource, opts, path) do
    alias MishkaGervaz.Resource.Info.Table, as: TableInfo

    url_sync_config = TableInfo.url_sync(resource)

    if url_sync_config && url_sync_config[:enabled] do
      prefix = Keyword.get(opts, :prefix, url_sync_config[:prefix])
      allowed_params = Keyword.get(opts, :allowed_params, url_sync_config[:params])

      max_filter_length =
        Keyword.get(opts, :max_filter_length, url_sync_config[:max_filter_length])

      allowed_filters =
        Keyword.get_lazy(opts, :allowed_filters, fn ->
          resource |> TableInfo.filters() |> Enum.map(& &1.name)
        end)

      path_params =
        TableInfo.config(resource)[:identity][:route]
        |> extract_path_params(path, max_filter_length || @default_max_filter_length)

      preserve_params_config = url_sync_config[:preserve_params]
      effective_max = max_filter_length || @default_max_filter_length

      url_state =
        max_filter_length
        |> then(
          &do_decode(params, prefix, allowed_params, allowed_filters, &1, path, path_params)
        )

      preserved =
        extract_preserved_params(params, prefix, preserve_params_config, effective_max)

      Map.put(url_state, :preserved_params, preserved)
    else
      nil
    end
  end

  @spec do_decode(
          map(),
          String.t() | nil,
          list(atom()),
          list(atom()) | nil,
          non_neg_integer() | nil,
          String.t() | nil,
          map()
        ) :: url_state()
  defp do_decode(
         params,
         prefix,
         allowed_params,
         allowed_filters,
         max_filter_length,
         path,
         path_params
       ) do
    decode_opts = [
      allowed_filters: allowed_filters,
      max_filter_length: max_filter_length
    ]

    %{
      filters:
        decode_if_allowed(:filters, allowed_params, fn ->
          decode_filters(params, prefix, decode_opts)
        end),
      sort: decode_if_allowed(:sort, allowed_params, fn -> decode_sort(params, prefix) end),
      page: decode_if_allowed(:page, allowed_params, fn -> decode_page(params, prefix) end),
      page_size:
        decode_if_allowed(:page_size, allowed_params, fn -> decode_page_size(params, prefix) end),
      search: decode_if_allowed(:search, allowed_params, fn -> decode_search(params, prefix) end),
      template:
        decode_if_allowed(:template, allowed_params, fn -> decode_template(params, prefix) end),
      path: path,
      path_params: path_params
    }
  end

  @spec decode_if_allowed(atom(), list(atom()), (-> any())) :: any()
  defp decode_if_allowed(param_type, allowed_params, decode_fn) do
    if param_type in allowed_params do
      decode_fn.()
    else
      default_for(param_type)
    end
  end

  @spec default_for(atom()) :: map() | list() | integer() | nil
  defp default_for(:filters), do: %{}
  defp default_for(:sort), do: []
  defp default_for(:page), do: 1
  defp default_for(:page_size), do: nil
  defp default_for(:search), do: nil
  defp default_for(:template), do: nil

  @doc """
  Apply URL state to existing table state.

  Merges decoded URL state with default table state.
  """
  @spec apply_url_state(map(), url_state()) :: map()
  def apply_url_state(state, url_state) do
    state
    |> maybe_apply_filters(url_state)
    |> maybe_apply_sort(url_state)
    |> maybe_apply_page(url_state)
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
      query = URI.encode_query(params)
      "#{base_path}?#{query}"
    end
  end

  @doc """
  Check if url_state matches current table state.

  Used to detect if incoming url_state is from our own push_patch
  (to avoid duplicate data reload).
  """
  @spec matches_state?(url_state() | nil, map()) :: boolean()
  def matches_state?(nil, _state), do: false

  def matches_state?(url_state, state) do
    url_state[:filters] == state.filter_values and
      url_state[:sort] == state.sort_fields and
      url_state[:page] == state.page and
      (url_state[:path_params] || %{}) == (Map.get(state, :path_params) || %{})
  end

  @spec maybe_encode_filters(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_filters(params, state, config, prefix) do
    if :filters in (config[:params] || []) do
      filters = Map.get(state, :filter_values, %{})

      Enum.reduce(filters, params, fn {key, value}, acc ->
        if is_nil(value) or value == "" do
          acc
        else
          param_key = build_key(prefix, "filter_#{key}")
          Map.put(acc, param_key, encode_value(value))
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
      filter_values = state.filter_values
      search = filter_values[:search] || filter_values[:q]

      if search && search != "" do
        Map.put(params, build_key(prefix, "search"), search)
      else
        params
      end
    else
      params
    end
  end

  @spec maybe_encode_template(map(), map(), map(), String.t() | nil) :: map()
  defp maybe_encode_template(params, state, config, prefix) do
    if :template in (config[:params] || []) do
      template = Map.get(state, :template)

      if template do
        template_name =
          if is_atom(template), do: template, else: template.name()

        Map.put(params, build_key(prefix, "template"), to_string(template_name))
      else
        params
      end
    else
      params
    end
  end

  @spec decode_filters(map(), String.t() | nil, keyword()) :: map()
  defp decode_filters(params, prefix, opts) do
    filter_prefix = build_key(prefix, "filter_")
    allowed_filters = Keyword.get(opts, :allowed_filters, nil)
    max_length = Keyword.get(opts, :max_filter_length, @default_max_filter_length)

    params
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, filter_prefix) end)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      field_name = String.replace_prefix(key, filter_prefix, "")

      with {:ok, field_atom} <- safe_to_existing_atom(field_name),
           true <- filter_allowed?(field_atom, allowed_filters),
           true <- value_length_valid?(value, max_length) do
        Map.put(acc, field_atom, value |> sanitize() |> decode_value())
      else
        _ -> acc
      end
    end)
  end

  @spec safe_to_existing_atom(String.t()) :: {:ok, atom()} | :error
  defp safe_to_existing_atom(string) do
    {:ok, String.to_existing_atom(string)}
  rescue
    ArgumentError -> :error
  end

  @spec filter_allowed?(atom(), list(atom()) | nil) :: boolean()
  defp filter_allowed?(_field, nil), do: true
  defp filter_allowed?(_field, []), do: true
  defp filter_allowed?(field, allowed_filters), do: field in allowed_filters

  @spec value_length_valid?(any(), non_neg_integer()) :: boolean()
  defp value_length_valid?(value, max_length) when is_binary(value) do
    String.length(value) <= max_length
  end

  defp value_length_valid?(value, max_length) when is_list(value) do
    Enum.all?(value, &value_length_valid?(&1, max_length))
  end

  defp value_length_valid?(_, _), do: true

  @spec decode_sort(map(), String.t() | nil) :: list({atom(), :asc | :desc})
  defp decode_sort(params, prefix) do
    key = build_key(prefix, "sort")

    case Map.get(params, key) do
      nil ->
        []

      sort_string ->
        sort_string
        |> String.split(",")
        |> Enum.map(&parse_sort_field/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  @spec decode_page(map(), String.t() | nil) :: pos_integer()
  defp decode_page(params, prefix) do
    key = build_key(prefix, "page")

    case Map.get(params, key) do
      nil -> 1
      page -> String.to_integer(page)
    end
  rescue
    _ -> 1
  end

  @spec decode_page_size(map(), String.t() | nil) :: pos_integer() | nil
  defp decode_page_size(params, prefix) do
    key = build_key(prefix, "page_size")

    case Map.get(params, key) do
      nil -> nil
      size_str ->
        size = String.to_integer(size_str)
        if size > 0, do: size, else: nil
    end
  rescue
    _ -> nil
  end

  @spec decode_search(map(), String.t() | nil) :: String.t() | nil
  defp decode_search(params, prefix) do
    key = build_key(prefix, "search")

    case Map.get(params, key) do
      nil -> nil
      value -> sanitize(value)
    end
  end

  @spec decode_template(map(), String.t() | nil) :: atom() | nil
  defp decode_template(params, prefix) do
    key = build_key(prefix, "template")

    case Map.get(params, key) do
      nil -> nil
      template -> String.to_existing_atom(template)
    end
  rescue
    _ -> nil
  end

  @spec maybe_apply_filters(map(), map()) :: map()
  defp maybe_apply_filters(state, %{filters: filters}) when filters != %{} do
    current = Map.get(state, :filter_values, %{})
    %{state | filter_values: Map.merge(current, filters)}
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

  @spec maybe_apply_search(map(), map()) :: map()
  defp maybe_apply_search(state, %{search: search}) when is_binary(search) and search != "" do
    current = Map.get(state, :filter_values, %{})
    %{state | filter_values: Map.put(current, :search, search)}
  end

  defp maybe_apply_search(state, _), do: state

  @spec maybe_apply_template(map(), map()) :: map()
  defp maybe_apply_template(state, %{template: template}) when not is_nil(template) do
    state
  end

  defp maybe_apply_template(state, _), do: state

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

    params
    |> Enum.reject(fn {key, _} ->
      Enum.any?(known_prefixes, &String.starts_with?(key, &1))
    end)
    |> Enum.filter(fn {_key, value} -> value_length_valid?(value, max_length) end)
    |> Enum.map(fn {key, value} -> {key, sanitize_preserved(value)} end)
    |> Map.new()
  end

  defp extract_preserved_params(params, _prefix, param_names, max_length)
       when is_list(param_names) do
    param_names
    |> Enum.reduce(%{}, fn name, acc ->
      key = to_string(name)

      case Map.fetch(params, key) do
        {:ok, value} ->
          if value_length_valid?(value, max_length) do
            Map.put(acc, key, sanitize_preserved(value))
          else
            acc
          end

        :error ->
          acc
      end
    end)
  end

  @spec known_param_prefixes(String.t() | nil) :: list(String.t())
  defp known_param_prefixes(prefix) do
    suffixes = ["filter_", "sort", "page", "page_size", "search", "template"]
    Enum.map(suffixes, &build_key(prefix, &1))
  end

  @spec sanitize_preserved(any()) :: any()
  defp sanitize_preserved(value) when is_binary(value) do
    sanitize(value)
  end

  defp sanitize_preserved(value) when is_list(value) do
    Enum.map(value, &sanitize_preserved/1)
  end

  defp sanitize_preserved(value), do: value

  @spec merge_preserved_params(map(), map()) :: map()
  defp merge_preserved_params(params, %{preserved_params: preserved})
       when is_map(preserved) and map_size(preserved) > 0 do
    Map.merge(params, preserved)
  end

  defp merge_preserved_params(params, _), do: params

  @spec build_key(String.t() | nil, String.t()) :: String.t()
  defp build_key(nil, suffix), do: suffix
  defp build_key("", suffix), do: suffix
  defp build_key(prefix, suffix), do: "#{prefix}_#{suffix}"

  @spec encode_value(any()) :: String.t()
  defp encode_value(value) when is_list(value), do: Enum.join(value, ",")
  defp encode_value(value) when is_atom(value), do: to_string(value)

  defp encode_value(%{from: from, to: to}) do
    "#{encode_date_value(from)}~#{encode_date_value(to)}"
  end

  defp encode_value(%{from: from}), do: "#{encode_date_value(from)}~"
  defp encode_value(%{to: to}), do: "~#{encode_date_value(to)}"
  defp encode_value(value), do: to_string(value)

  defp encode_date_value(%Date{} = date), do: Date.to_iso8601(date)
  defp encode_date_value(value) when is_binary(value), do: value
  defp encode_date_value(value), do: to_string(value)

  @spec decode_value(any()) :: any()
  defp decode_value(value) when is_binary(value) do
    cond do
      String.contains?(value, "~") -> decode_date_range(value)
      String.contains?(value, ",") -> String.split(value, ",")
      true -> value
    end
  end

  defp decode_value(value), do: value

  defp decode_date_range(value) do
    case String.split(value, "~", parts: 2) do
      [from, to] when from != "" and to != "" -> %{from: from, to: to}
      [from, ""] when from != "" -> %{from: from}
      ["", to] when to != "" -> %{to: to}
      _ -> value
    end
  end

  @spec parse_sort_field(String.t()) :: {atom(), :asc | :desc} | nil
  defp parse_sort_field(field_str) do
    case String.split(field_str, ":") do
      [field, "asc"] -> {String.to_existing_atom(field), :asc}
      [field, "desc"] -> {String.to_existing_atom(field), :desc}
      [field] -> {String.to_existing_atom(field), :asc}
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @spec sanitize(any()) :: any()
  defp sanitize(value) when is_binary(value) do
    HtmlSanitizeEx.strip_tags(value)
  rescue
    _ -> value
  end

  defp sanitize(value) when is_list(value), do: Enum.map(value, &sanitize/1)
  defp sanitize(value), do: value

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
          with {:ok, atom_name} <- safe_to_existing_atom(param_name),
               true <- value_length_valid?(value, max_length) do
            Map.put(acc, atom_name, sanitize(value))
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

  @dialyzer {:nowarn_function, extract_path: 1}
  @spec extract_path(String.t() | any()) :: String.t() | nil
  defp extract_path(uri) when is_binary(uri) do
    %URI{path: path} = URI.parse(uri)
    path
  end

  defp extract_path(_), do: nil
end
