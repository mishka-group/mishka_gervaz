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
  """

  alias MishkaGervaz.Table.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.DataLoader.Builder

      alias MishkaGervaz.Table.Web.State

      @doc """
      Load a page of data with the given query, action, and tenant.
      Returns tuple of {page, page_result, reset?, pagination_info}.
      """
      @spec load_page(State.t(), Ash.Query.t(), integer(), atom(), any()) ::
              {integer(), Ash.Page.Offset.t() | map(), boolean(), map()}
      def load_page(state, query, page, action, tenant) do
        page_size = state.current_page_size || state.static.page_size

        if is_nil(page_size) do
          results =
            query
            |> Ash.Query.for_read(action, %{}, actor: state.current_user, tenant: tenant)
            |> Ash.read!()

          page_result = %{results: results, count: length(results), more?: false}
          {1, page_result, true, %{}}
        else
          pagination_type = get_pagination_type(state)
          page_opts = build_page_opts(page, page_size, pagination_type)

          page_result =
            query
            |> Ash.Query.for_read(action, %{}, actor: state.current_user, tenant: tenant)
            |> Ash.read!(page: page_opts)

          pagination_info = build_pagination_info(pagination_type, page_result, page_size)

          {page, page_result, page == 1, pagination_info}
        end
      end

      @doc """
      Get pagination type from state config.
      """
      @spec get_pagination_type(State.t()) :: :numbered | :infinite
      def get_pagination_type(state) do
        state.static.config.pagination.type
      end

      @doc """
      Build page options for Ash.read.
      """
      @spec build_page_opts(integer(), integer(), :numbered | :infinite) :: keyword()
      def build_page_opts(page, page_size, pagination_type) do
        opts = [offset: (page - 1) * page_size, limit: page_size]

        if pagination_type == :numbered do
          Keyword.put(opts, :count, true)
        else
          opts
        end
      end

      @doc """
      Build pagination info from result.
      """
      @spec build_pagination_info(:numbered | :infinite, Ash.Page.Offset.t(), integer()) :: map()
      def build_pagination_info(:numbered, page_result, page_size) do
        total_count = page_result.count || 0
        total_pages = calculate_total_pages(total_count, page_size)
        %{total_count: total_count, total_pages: total_pages}
      end

      def build_pagination_info(_pagination_type, _page_result, _page_size), do: %{}

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
                     build_page_opts: 3,
                     build_pagination_info: 3,
                     calculate_total_pages: 2
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.PaginationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.PaginationHandler
end
