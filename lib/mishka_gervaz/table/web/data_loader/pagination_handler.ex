defmodule MishkaGervaz.Table.Web.DataLoader.PaginationHandler do
  @moduledoc """
  Handles pagination logic for data loading.

  ## Overridable Functions

  - `load_page/5` - Load a specific page of data
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
          page_opts = build_page_opts(page, page_size, pagination_type, count?, keep?)

          page_result =
            query
            |> Ash.Query.for_read(action, %{}, actor: state.current_user, tenant: tenant)
            |> Ash.read!(page: page_opts)

          pagination_info = build_pagination_info(pagination_type, page_result, page_size, count?)

          {page, page_result, keep? or reset_stream?(pagination_type, page), pagination_info}
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

      Normally page N is the Nth slice — `offset: (N-1) * size`. For a table that declared
      `keep_loaded_records true` it is the first N slices instead, read in one query from offset 0.
      Those tables render the whole loaded list from state rather than appending to a stream, so one
      read must return everything the reader already had.
      """
      @spec build_page_opts(integer(), integer(), atom(), boolean(), boolean()) :: keyword()
      def build_page_opts(page, page_size, _pagination_type, count?, keep_loaded_records?) do
        opts =
          if keep_loaded_records?,
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
