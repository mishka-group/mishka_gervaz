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

      Load more (and infinite scroll) reads the page after the last row the view read. When the
      read action allows keyset pagination (`pagination keyset?: true`), it reads after that row's
      keyset, the state's `after_keyset`, so a row realtime puts in or takes out anywhere in the
      list moves no row past it, and one read is all it costs. It reads from an offset instead when
      the action has no keyset pagination, when the rows carry no keyset, or when Ash refuses the
      keyset as invalid: after the rows kept for a table with `keep_loaded_records true`, and the
      Nth slice for any other table, where a row removed elsewhere moves the next row past Load
      more. A numbered page is always the Nth slice.

      Load earlier (`loading_type: :earlier`) reads the page before the first row the view shows, by
      that row's keyset, the state's `before_keyset`, the same way, or the page's slice by offset
      without keyset. Its rows go above the rows shown, so it never clears them.

      A load of a table with `keep_loaded_records true` that starts its list afresh at page N of a
      list that grows (Load more and infinite), such as one opened at page N or reloaded after a
      bulk action, reads the first N pages, so the rows the reader had stay.
      """
      @spec load_page(State.t(), Ash.Query.t(), integer(), atom(), any()) ::
              {integer(), Ash.Page.page() | map(), boolean(), map()}
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
          kind = read_kind(state.loading_type, pagination_type, page)

          read_query =
            Ash.Query.for_read(query, action, %{}, actor: state.current_user, tenant: tenant)

          page_result =
            read_page(
              read_query,
              keyset_opts(state, kind, read_query, page_size, count?),
              page_opts(state, kind, page, page_size, pagination_type, count?, keep?)
            )

          pagination_info = build_pagination_info(pagination_type, page_result, page_size, count?)

          {page, page_result, kind == :reset and (reset_stream?(pagination_type, page) or keep?),
           pagination_info}
        end
      end

      @spec read_kind(atom(), atom(), pos_integer()) :: :reset | :more | :earlier
      defp read_kind(:earlier, _type, _page), do: :earlier

      defp read_kind(:more, type, page),
        do: if(reset_stream?(type, page), do: :reset, else: :more)

      defp read_kind(_loading_type, _type, _page), do: :reset

      @spec page_opts(
              State.t(),
              :reset | :more | :earlier,
              pos_integer(),
              pos_integer(),
              atom(),
              boolean(),
              boolean()
            ) :: keyword()
      defp page_opts(state, :more, page, page_size, type, count?, true) do
        page
        |> build_page_opts(page_size, type, count?)
        |> Keyword.put(:offset, length(state.loaded_records))
      end

      defp page_opts(_state, :reset, page, page_size, type, count?, keep?),
        do:
          build_page_opts(page, page_size, type, count?, keep? and not reset_stream?(type, page))

      defp page_opts(_state, _kind, page, page_size, type, count?, _keep?),
        do: build_page_opts(page, page_size, type, count?)

      @spec keyset_opts(
              State.t(),
              :reset | :more | :earlier,
              Ash.Query.t(),
              pos_integer(),
              boolean()
            ) :: keyword() | nil
      defp keyset_opts(
             state,
             kind,
             %Ash.Query{action: %{pagination: %{keyset?: true}}},
             page_size,
             count?
           ) do
        case cursor(state, kind) do
          {direction, keyset} when is_binary(keyset) ->
            [{direction, keyset}, limit: page_size] ++ if(count?, do: [count: true], else: [])

          _no_cursor ->
            nil
        end
      end

      defp keyset_opts(_state, _kind, _query, _page_size, _count?), do: nil

      @spec cursor(State.t(), :reset | :more | :earlier) :: {:after | :before, term()} | nil
      defp cursor(%State{after_keyset: keyset}, :more), do: {:after, keyset}
      defp cursor(%State{before_keyset: keyset}, :earlier), do: {:before, keyset}
      defp cursor(_state, :reset), do: nil

      @spec read_page(Ash.Query.t(), keyword() | nil, keyword()) :: Ash.Page.page()
      defp read_page(query, nil, page_opts),
        do: query |> Ash.read!(page: page_opts) |> read_rest(query, page_opts)

      defp read_page(query, keyset_opts, page_opts) do
        case Ash.read(query, page: keyset_opts) do
          {:ok, page} -> read_rest(page, query, keyset_opts)
          {:error, %Ash.Error.Invalid{}} -> read_page(query, nil, page_opts)
          {:error, error} -> raise Ash.Error.to_error_class(error)
        end
      end

      @spec read_rest(Ash.Page.page(), Ash.Query.t(), keyword()) :: Ash.Page.page()
      defp read_rest(page, query, opts),
        do: read_rest(page, query, opts, direction(opts), opts[:limit])

      defp read_rest(
             %{more?: true, results: [_ | _] = rows} = page,
             query,
             opts,
             direction,
             limit
           )
           when length(rows) < limit do
        rest = Ash.read!(query, page: rest_opts(direction, rows, opts, limit - length(rows)))
        rows = join_rows(direction, rows, rest.results)
        read_rest(%{page | results: rows, more?: rest.more?}, query, opts, direction, limit)
      end

      defp read_rest(page, _query, _opts, _direction, _limit), do: page

      @spec direction(keyword()) :: :after | :before | :offset
      defp direction(opts) do
        cond do
          Keyword.has_key?(opts, :after) -> :after
          Keyword.has_key?(opts, :before) -> :before
          true -> :offset
        end
      end

      @spec rest_opts(:after | :before | :offset, list(), keyword(), pos_integer()) :: keyword()
      defp rest_opts(:after, rows, _opts, limit),
        do: [after: List.last(rows).__metadata__.keyset, limit: limit]

      defp rest_opts(:before, [first | _rows], _opts, limit),
        do: [before: first.__metadata__.keyset, limit: limit]

      defp rest_opts(:offset, rows, opts, limit),
        do: [offset: Keyword.get(opts, :offset, 0) + length(rows), limit: limit]

      @spec join_rows(:after | :before | :offset, list(), list()) :: list()
      defp join_rows(:before, rows, rest), do: rest ++ rows
      defp join_rows(_direction, rows, rest), do: rows ++ rest

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
