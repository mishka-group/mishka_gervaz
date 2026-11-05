defmodule MishkaGervaz.Table.Web.DataLoader.PaginationHandler do
  @moduledoc """
  Handles pagination logic for data loading.

  ## Overridable Functions

  - `load_page/5` - Load a specific page of data
  - `load_total/4` - Read the table's total without loading a page; a `load_page/5` override that
    changes the read or how its total is produced overrides this too, or returns `:skip`
  - `get_pagination_type/1` - Get pagination type from state
  - `calculate_total_pages/2` - Calculate total pages from count
  - `build_page_opts/3` - Build pagination options for query

  ## User Override

      defmodule MyApp.Table.DataLoader.PaginationHandler do
        use MishkaGervaz.Table.Web.DataLoader.PaginationHandler

        def load_page(state, query, page, action, tenant) do
          # Custom pagination with caching
          cached_result = check_cache(state.static.resource, page)

          if cached_result do
            cached_result
          else
            result = super(state, query, page, action, tenant)
            cache_result(state.static.resource, page, result)
            result
          end
        end
      end

  See `MishkaGervaz.Table.Web.DataLoader`,
  `MishkaGervaz.Table.Web.DataLoader.Helpers`,
  `MishkaGervaz.Table.Entities.Pagination`,
  and the sibling sub-builders `QueryBuilder`, `FilterParser`,
  `TenantResolver`, `HookRunner`, `RelationLoader`.
  """

  @doc false
  @spec extract_results(any()) :: list()
  def extract_results(%{results: results}) when is_list(results), do: results
  def extract_results(results) when is_list(results), do: results
  def extract_results(_), do: []

  defmacro __using__(_opts) do
    quote do
      alias MishkaGervaz.Table.Web.State

      import MishkaGervaz.Table.Web.DataLoader.PaginationHandler, only: [extract_results: 1]

      @doc """
      Load a page of data with the given query, action, and tenant.
      Returns tuple of {page, page_result, reset?, pagination_info}.

      The page holds every row its page options ask for. A read action whose `max_page_size` is
      smaller returns at most that many rows a read, so the rest are read after them, as many reads
      as it takes, until the page is full or the read has no more rows. Each read stays within the
      action's `max_page_size`.

      A table with `keep_loaded_records true` adds a page to the rows it keeps: Load more reads one
      page, after the rows kept, so a row taken out of them or put in over realtime moves no row
      past it. A load of such a table that starts its list afresh at page N of a list that grows
      (Load more and infinite), such as one opened at page N or reloaded after a bulk action, reads
      the first N pages, so the rows the reader had stay.
      """
      @spec load_page(State.t(), Ash.Query.t(), integer(), atom(), any()) ::
              {integer(), Ash.Page.Offset.t() | map(), boolean(), map()}
      def load_page(state, query, page, action, tenant) do
        page_size = state.current_page_size || state.static.page_size

        if is_nil(state.static.config[:pagination]) or is_nil(page_size) do
          read_result =
            query
            |> Ash.Query.for_read(action, %{}, actor: state.current_user, tenant: tenant)
            |> Ash.read!()

          results = extract_results(read_result)
          page_result = %{results: results, count: length(results), more?: false}
          {1, page_result, true, %{}}
        else
          pagination_type = get_pagination_type(state)
          count? = count_requested?(state, pagination_type)
          keep? = state.static.keep_loaded_records == true
          more? = state.loading_type == :more and not reset_stream?(pagination_type, page)

          page_opts =
            keep_page_opts(state, page, page_size, pagination_type, count?, keep?, more?)

          read_query =
            Ash.Query.for_read(query, action, %{}, actor: state.current_user, tenant: tenant)

          page_result =
            read_query
            |> Ash.read!(page: page_opts)
            |> read_rest(read_query, page_opts[:offset] || 0, page_opts[:limit])

          pagination_info = build_pagination_info(pagination_type, page_result, page_size, count?)

          {page, page_result, reset_stream?(pagination_type, page) or (keep? and not more?),
           pagination_info}
        end
      end

      @spec keep_page_opts(
              State.t(),
              pos_integer(),
              pos_integer(),
              atom(),
              boolean(),
              boolean(),
              boolean()
            ) :: keyword()
      defp keep_page_opts(state, page, page_size, type, count?, true, true) do
        page
        |> build_page_opts(page_size, type, count?)
        |> Keyword.put(:offset, length(state.loaded_records))
      end

      defp keep_page_opts(_state, page, page_size, type, count?, keep?, _more?),
        do:
          build_page_opts(page, page_size, type, count?, keep? and not reset_stream?(type, page))

      @spec read_rest(Ash.Page.Offset.t(), Ash.Query.t(), non_neg_integer(), pos_integer()) ::
              Ash.Page.Offset.t()
      defp read_rest(%{more?: true, results: [_ | _] = rows} = page, query, offset, limit)
           when length(rows) < limit do
        read = length(rows)
        rest = Ash.read!(query, page: [offset: offset + read, limit: limit - read])

        read_rest(
          %{page | results: rows ++ rest.results, more?: rest.more?},
          query,
          offset,
          limit
        )
      end

      defp read_rest(page, _query, _offset, _limit), do: page

      @doc """
      The table's total as `load_page/5` would report it, without loading a page.

      Returns `{:ok, %{total_count: count, total_pages: pages}}` for the same query, action and
      tenant — `total_pages` is `nil` for a table without pagination. It is counted with
      `Ash.count/2`, unless that could differ from what the read reports: a manual read, a query
      carrying its own `full_count` in its context or a `before_action`, a table without pagination
      on an action that paginates, and a data layer that cannot count all read instead — one row
      with `count: true`, or every row for a table without pagination. Returns `:skip` when the
      table keeps no count — a type other than `:numbered` with `show_total false` — or when the
      read returns an error. A read that raises raises here too, as it does in `load_page/5`.
      """
      @spec load_total(State.t(), Ash.Query.t(), atom(), any()) ::
              {:ok, %{total_count: non_neg_integer(), total_pages: pos_integer() | nil}} | :skip
      def load_total(state, query, action, tenant) do
        page_size = state.current_page_size || state.static.page_size
        paginated? = not is_nil(state.static.config[:pagination]) and not is_nil(page_size)

        if paginated? and not count_requested?(state, get_pagination_type(state)) do
          :skip
        else
          query
          |> Ash.Query.for_read(action, %{}, actor: state.current_user, tenant: tenant)
          |> count_rows(paginated?)
          |> case do
            {:ok, count} when paginated? ->
              {:ok, %{total_count: count, total_pages: calculate_total_pages(count, page_size)}}

            {:ok, count} ->
              {:ok, %{total_count: count, total_pages: nil}}

            :error ->
              :skip
          end
        end
      end

      @spec count_rows(Ash.Query.t(), boolean()) :: {:ok, non_neg_integer()} | :error
      defp count_rows(query, paginated?) do
        if count_by_reading?(query, paginated?) do
          read_count(query, paginated?)
        else
          case Ash.count(query) do
            {:ok, count} when is_integer(count) -> {:ok, count}
            _cannot_count -> read_count(query, paginated?)
          end
        end
      end

      @spec count_by_reading?(Ash.Query.t(), boolean()) :: boolean()
      defp count_by_reading?(%Ash.Query{action: action} = query, paginated?) do
        not is_nil(Map.get(action, :manual)) or
          not is_nil((query.context || %{})[:full_count]) or
          query.before_action != [] or
          (not paginated? and Map.get(action, :pagination) not in [false, nil])
      end

      @spec read_count(Ash.Query.t(), boolean()) :: {:ok, non_neg_integer()} | :error
      defp read_count(query, true) do
        case Ash.read(query, page: [offset: 0, limit: 1, count: true]) do
          {:ok, %{count: count}} when is_integer(count) -> {:ok, count}
          _no_count -> :error
        end
      end

      defp read_count(query, false) do
        case Ash.read(query) do
          {:ok, read_result} -> {:ok, length(extract_results(read_result))}
          {:error, _error} -> :error
        end
      end

      @doc """
      Whether this page replaces what is on screen or adds to it.

      A numbered page always replaces. Load-more and infinite build a list as you go, so only their
      first page clears it.
      """
      @spec reset_stream?(atom(), pos_integer()) :: boolean()
      def reset_stream?(:numbered, _page), do: true
      def reset_stream?(_type, page), do: page == 1

      @doc """
      Get pagination type from state config.
      """
      @spec get_pagination_type(State.t()) :: :numbered | :infinite
      def get_pagination_type(state) do
        state.static.config.pagination.type
      end

      @doc """
      Whether this read should ask the data layer for a total count.

      `:numbered` always needs one to size its page list. Any other type needs one only if the table
      asked to show a total (`pagination do ui do show_total true end end`) — counting is a second
      query, and the read must be `countable`, so it stays opt-in.
      """
      @spec count_requested?(State.t(), atom()) :: boolean()
      def count_requested?(_state, :numbered), do: true

      def count_requested?(%{static: %{pagination_ui: %{show_total: true}}}, _type), do: true

      def count_requested?(_state, _type), do: false

      @doc """
      Build page options for Ash.read.
      """
      @spec build_page_opts(integer(), integer(), :numbered | :infinite) :: keyword()
      def build_page_opts(page, page_size, pagination_type),
        do: build_page_opts(page, page_size, pagination_type, pagination_type == :numbered)

      @spec build_page_opts(integer(), integer(), atom(), boolean()) :: keyword()
      def build_page_opts(page, page_size, pagination_type, count?),
        do: build_page_opts(page, page_size, pagination_type, count?, false)

      @doc """
      Page options for one read.

      Page N is the Nth slice — `offset: (N-1) * size`. With `from_start?` it is the first N slices
      instead, read from offset 0: `load_page/5` asks for that when a table with
      `keep_loaded_records true` starts its growing list afresh at page N, so the rows the reader
      had stay, and reads it in as many reads as the read action's `max_page_size` needs.
      """
      @spec build_page_opts(integer(), integer(), atom(), boolean(), boolean()) :: keyword()
      def build_page_opts(page, page_size, _pagination_type, count?, from_start?) do
        opts =
          if from_start?,
            do: [offset: 0, limit: page * page_size],
            else: [offset: (page - 1) * page_size, limit: page_size]

        if count?, do: Keyword.put(opts, :count, true), else: opts
      end

      @doc """
      Build pagination info from result.
      """
      @spec build_pagination_info(:numbered | :infinite, Ash.Page.Offset.t(), integer()) :: map()
      def build_pagination_info(pagination_type, page_result, page_size),
        do:
          build_pagination_info(
            pagination_type,
            page_result,
            page_size,
            pagination_type == :numbered
          )

      @spec build_pagination_info(atom(), Ash.Page.Offset.t(), integer(), boolean()) :: map()
      def build_pagination_info(_pagination_type, page_result, page_size, true) do
        total_count = page_result.count || 0
        total_pages = calculate_total_pages(total_count, page_size)
        %{total_count: total_count, total_pages: total_pages}
      end

      def build_pagination_info(_pagination_type, _page_result, _page_size, false), do: %{}

      @doc """
      Calculate total pages from count and page size.
      """
      @spec calculate_total_pages(integer(), integer()) :: integer()
      def calculate_total_pages(0, _page_size), do: 1

      def calculate_total_pages(total_count, page_size) do
        ceil(total_count / page_size)
      end

      defoverridable load_page: 5,
                     load_total: 4,
                     get_pagination_type: 1,
                     count_requested?: 2,
                     reset_stream?: 2,
                     build_page_opts: 3,
                     build_page_opts: 4,
                     build_pagination_info: 3,
                     build_pagination_info: 4,
                     calculate_total_pages: 2
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.PaginationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.PaginationHandler
end
