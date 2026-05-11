defmodule MishkaGervaz.Table.Web.State.UrlSync do
  @moduledoc """
  Handles URL synchronization for table state.

  ## Overridable Functions

  - `apply_url_state/2` - Apply URL state to table state
  - `bidirectional?/1` - Check if bidirectional sync is enabled

  ## User Override

      defmodule MyApp.Table.UrlSync do
        use MishkaGervaz.Table.Web.State.UrlSync

        def apply_url_state(state, url_state) do
          state
          |> super(url_state)
          |> apply_custom_url_params(url_state)
        end
      end

  See `MishkaGervaz.Table.Web.State`,
  `MishkaGervaz.Table.Web.State.Helpers`,
  `MishkaGervaz.Table.Web.UrlSync` (the outer-LiveView URL bridge),
  and the sibling builders `ColumnBuilder`, `FilterBuilder`,
  `ActionBuilder`, `Presentation`, `Access`.
  """

  import MishkaGervaz.Helpers, only: [accessible?: 2, find_by_name: 2]

  @doc false
  @spec apply_url_filters(map(), map()) :: map()
  def apply_url_filters(state, %{filters: filters}) when filters != %{} do
    valid_filters = validate_url_filters(filters, state)
    merged = Map.merge(state.filter_values, valid_filters)
    %{state | filter_values: merged}
  end

  def apply_url_filters(state, %{filters: _filters}) do
    %{state | filter_values: %{}, relation_filter_state: %{}}
  end

  def apply_url_filters(state, _), do: state

  defp validate_url_filters(url_filters, state) do
    url_filters
    |> Enum.filter(fn {name, _value} ->
      case find_by_name(state.static.filters, name) do
        nil -> false
        %{visible: false} -> true
        filter -> accessible?(filter, state)
      end
    end)
    |> Map.new()
  end

  @doc false
  @spec apply_url_sort(map(), map()) :: map()
  def apply_url_sort(state, %{sort: sort}) when sort != [] do
    %{state | sort_fields: sort}
  end

  def apply_url_sort(state, _), do: state

  @doc false
  @spec apply_url_page(map(), map()) :: map()
  def apply_url_page(state, %{page: page}) when is_integer(page) and page > 0 do
    %{state | page: page}
  end

  def apply_url_page(state, _), do: state

  @doc false
  @spec apply_url_search(map(), map()) :: map()
  def apply_url_search(state, %{search: search}) when is_binary(search) and search != "" do
    merged = Map.put(state.filter_values, :search, search)
    %{state | filter_values: merged}
  end

  def apply_url_search(state, _), do: state

  @doc false
  @spec apply_url_path(map(), map()) :: map()
  def apply_url_path(state, %{path: path}) when is_binary(path) do
    %{state | base_path: path}
  end

  def apply_url_path(state, _), do: state

  @doc false
  @spec apply_url_path_params(map(), map()) :: map()
  def apply_url_path_params(state, %{path_params: params})
      when is_map(params) and map_size(params) > 0 do
    %{state | path_params: params}
  end

  def apply_url_path_params(state, _), do: state

  @doc false
  @spec apply_url_preserved_params(map(), map()) :: map()
  def apply_url_preserved_params(state, %{preserved_params: params})
      when is_map(params) and map_size(params) > 0 do
    %{state | preserved_params: params}
  end

  def apply_url_preserved_params(state, _), do: state

  @doc false
  @spec apply_url_page_size(map(), map()) :: map()
  def apply_url_page_size(state, %{page_size: ps}) when is_integer(ps) and ps > 0 do
    max = state.static.max_page_size
    options = state.static.page_size_options
    clamped = if max, do: min(ps, max), else: ps

    effective =
      if options && clamped not in options do
        state.static.page_size
      else
        clamped
      end

    %{state | current_page_size: effective}
  end

  def apply_url_page_size(state, _), do: state

  @doc false
  defmacro __using__(_opts) do
    quote do
      import MishkaGervaz.Table.Web.State.UrlSync,
        only: [
          apply_url_filters: 2,
          apply_url_sort: 2,
          apply_url_page: 2,
          apply_url_search: 2,
          apply_url_path: 2,
          apply_url_path_params: 2,
          apply_url_preserved_params: 2,
          apply_url_page_size: 2
        ]

      @doc """
      Applies URL state to table state.

      ## Parameters

        - `state` - The current table state map
        - `url_state` - The URL state map to apply (or nil)

      ## Returns

        - The updated table state with URL state applied
      """
      @spec apply_url_state(map(), nil) :: map()
      def apply_url_state(state, nil), do: state

      @spec apply_url_state(map(), map()) :: map()
      def apply_url_state(state, url_state) when is_map(url_state) do
        state
        |> apply_url_filters(url_state)
        |> apply_url_sort(url_state)
        |> apply_url_page(url_state)
        |> apply_url_search(url_state)
        |> apply_url_path(url_state)
        |> apply_url_path_params(url_state)
        |> apply_url_preserved_params(url_state)
        |> apply_url_page_size(url_state)
      end

      @doc """
      Checks if bidirectional URL sync is enabled.

      ## Parameters

        - `state` - The table state map

      ## Returns

        - `true` if bidirectional sync is enabled, `false` otherwise
      """
      @spec bidirectional?(map()) :: boolean()
      def bidirectional?(%{static: %{url_sync_config: config}}) do
        config[:enabled] == true and config[:mode] == :bidirectional
      end

      @spec bidirectional?(term()) :: boolean()
      def bidirectional?(_), do: false

      defoverridable apply_url_state: 2, bidirectional?: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.UrlSync.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.UrlSync
end
