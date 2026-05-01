defmodule MishkaGervaz.Table.Web.DataLoader do
  @moduledoc """
  Handles async data loading with streams for MishkaGervaz tables.

  This module manages:
  - Initial data loading
  - Pagination (load more)
  - Filtering and sorting
  - Stream management
  - Async result handling

  ## Sub-builders

  DataLoader is composed of sub-builders that can be overridden:

  - `QueryBuilder` - Builds queries with filters and sorting
  - `FilterParser` - Parses raw filter values
  - `PaginationHandler` - Handles page loading and calculations
  - `TenantResolver` - Resolves tenant and actions
  - `HookRunner` - Executes lifecycle hooks

  ## User Override

  Override the entire data_loader module:

      defmodule MyApp.Table.DataLoader do
        use MishkaGervaz.Table.Web.DataLoader

        def load_async(socket, state, opts) do
          # Custom loading logic
          super(socket, state, opts)
        end
      end

  Override specific sub-builders:

      defmodule MyApp.Table.DataLoader do
        use MishkaGervaz.Table.Web.DataLoader,
          query: MyApp.Table.DataLoader.QueryBuilder,
          pagination: MyApp.Table.DataLoader.PaginationHandler
      end

  Or override via DSL:

      mishka_gervaz do
        table do
          data_loader do
            query MyApp.Table.DataLoader.QueryBuilder
            pagination MyApp.Table.DataLoader.PaginationHandler
          end
        end
      end

  Override entire data_loader module via DSL (positional argument):

      mishka_gervaz do
        table do
          data_loader MyApp.Table.CustomDataLoader
        end
      end
  """

  alias MishkaGervaz.Table.Web.{State, UrlSync}
  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Errors
  alias Phoenix.LiveView.AsyncResult

  require Phoenix.LiveView

  @spec maybe_load(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate maybe_load(socket, state), to: __MODULE__.Default

  @spec load_async(Phoenix.LiveView.Socket.t(), State.t(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate load_async(socket, state, opts \\ []), to: __MODULE__.Default

  @spec handle_async(atom(), {:ok, any()} | {:exit, any()}, Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate handle_async(name, result, socket), to: __MODULE__.Default

  @spec reload(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate reload(socket, state), to: __MODULE__.Default

  @spec load_more(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate load_more(socket, state), to: __MODULE__.Default

  @spec apply_filters(Phoenix.LiveView.Socket.t(), State.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate apply_filters(socket, state, new_filters), to: __MODULE__.Default

  @spec apply_sort(Phoenix.LiveView.Socket.t(), State.t(), atom()) :: Phoenix.LiveView.Socket.t()
  defdelegate apply_sort(socket, state, field), to: __MODULE__.Default

  @spec apply_archive_status(Phoenix.LiveView.Socket.t(), State.t(), :active | :archived) ::
          Phoenix.LiveView.Socket.t()
  defdelegate apply_archive_status(socket, state, status), to: __MODULE__.Default

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias MishkaGervaz.Table.Web.{State, UrlSync}
      alias MishkaGervaz.Resource.Info.Table, as: Info
      alias MishkaGervaz.Errors
      alias Phoenix.LiveView.AsyncResult

      require Phoenix.LiveView

      @__query_builder__ Keyword.get(
                           opts,
                           :query,
                           MishkaGervaz.Table.Web.DataLoader.QueryBuilder.Default
                         )
      @__filter_parser__ Keyword.get(
                           opts,
                           :filter_parser,
                           MishkaGervaz.Table.Web.DataLoader.FilterParser.Default
                         )
      @__pagination_handler__ Keyword.get(
                                opts,
                                :pagination,
                                MishkaGervaz.Table.Web.DataLoader.PaginationHandler.Default
                              )
      @__tenant_resolver__ Keyword.get(
                             opts,
                             :tenant,
                             MishkaGervaz.Table.Web.DataLoader.TenantResolver.Default
                           )
      @__hook_runner__ Keyword.get(
                         opts,
                         :hooks,
                         MishkaGervaz.Table.Web.DataLoader.HookRunner.Default
                       )
      @__relation_loader__ Keyword.get(
                             opts,
                             :relation,
                             MishkaGervaz.Table.Web.DataLoader.RelationLoader.Default
                           )

      @spec query_builder() :: module()
      def query_builder, do: @__query_builder__

      @spec filter_parser() :: module()
      def filter_parser, do: @__filter_parser__

      @spec pagination_handler() :: module()
      def pagination_handler, do: @__pagination_handler__

      @spec tenant_resolver() :: module()
      def tenant_resolver, do: @__tenant_resolver__

      @spec hook_runner() :: module()
      def hook_runner, do: @__hook_runner__

      @spec relation_loader() :: module()
      def relation_loader, do: @__relation_loader__

      @doc """
      Start loading data if needed.
      Called from LiveComponent update to trigger initial load.
      """
      @spec maybe_load(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
      def maybe_load(socket, %State{loading: :initial} = state) do
        load_async(socket, state, page: 1, reset: true)
      end

      def maybe_load(socket, _state), do: socket

      @doc """
      Load data asynchronously.

      ## Options

      - `:page` - Page number to load (default: 1)
      - `:reset` - Whether to reset the stream (default: false)
      """
      @spec load_async(Phoenix.LiveView.Socket.t(), State.t(), keyword()) ::
              Phoenix.LiveView.Socket.t()
      def load_async(socket, state, opts \\ []) do
        page = Keyword.get(opts, :page, 1)
        reset = Keyword.get(opts, :reset, false)
        loading_type = if reset, do: :reset, else: :more

        query_mod = resolve_query_builder(state.static.resource)
        hook_mod = resolve_hook_runner(state.static.resource)

        query = query_mod.build_query(state)

        query =
          state.static.hooks
          |> hook_mod.run_hook(:on_load, [query, state])
          |> hook_mod.apply_hook_result(query)

        state = State.update(state, loading: :loading, loading_type: loading_type)

        socket
        |> Phoenix.Component.assign(:table_state, state)
        |> Phoenix.LiveView.start_async(:load_data, fn ->
          execute_load(state, query, page)
        end)
      end

      @spec execute_load(State.t(), Ash.Query.t(), pos_integer()) ::
              {pos_integer(), map(), boolean(), keyword()}
      defp execute_load(state, query, page) do
        pagination_mod = resolve_pagination_handler(state.static.resource)
        tenant_mod = resolve_tenant_resolver(state.static.resource)

        action = tenant_mod.get_read_action(state)
        tenant = tenant_mod.get_tenant(state)

        pagination_mod.load_page(state, query, page, action, tenant)
      end

      @doc """
      Handle async result from data loading.
      """
      @spec handle_async(atom(), {:ok, any()} | {:exit, any()}, Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def handle_async(:load_data, {:ok, {page, page_result, reset, pagination_info}}, socket) do
        state = socket.assigns.table_state

        records =
          MishkaGervaz.Helpers.inject_preload_aliases(page_result.results, state.preload_aliases)

        state =
          State.update(state,
            loading: :loaded,
            has_initial_data?: true,
            page: page,
            has_more?: page_result.more?,
            total_count: pagination_info[:total_count],
            total_pages: pagination_info[:total_pages],
            records_result: AsyncResult.ok(state.records_result, %{page: page, data: page_result})
          )

        socket
        |> Phoenix.Component.assign(:table_state, state)
        |> Phoenix.LiveView.stream(state.static.stream_name, records, reset: reset)
        |> maybe_sync_url(state)
        |> MishkaGervaz.Table.Web.AutoState.after_load(state)
      end

      def handle_async(:load_data, {:exit, reason}, socket) do
        state = socket.assigns.table_state

        error =
          Errors.Data.LoadFailed.exception(
            resource: state.static.resource,
            reason: reason,
            page: state.page
          )

        state =
          State.update(state,
            loading: :error,
            records_result: AsyncResult.failed(state.records_result, error)
          )

        Phoenix.Component.assign(socket, :table_state, state)
      end

      @doc """
      Reload data with current filters/sort (for refresh after changes).
      """
      @spec reload(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
      def reload(socket, state) do
        load_async(socket, state, page: 1, reset: true)
      end

      @doc """
      Load next page (for pagination).
      """
      @spec load_more(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
      def load_more(socket, %State{page: current_page, has_more?: true} = state) do
        load_async(socket, state, page: current_page + 1, reset: false)
      end

      def load_more(socket, _state), do: socket

      @doc """
      Apply new filters and reload.
      """
      @spec apply_filters(Phoenix.LiveView.Socket.t(), State.t(), map()) ::
              Phoenix.LiveView.Socket.t()
      def apply_filters(socket, state, new_filters) do
        filter_mod = resolve_filter_parser(state.static.resource)
        parsed_filters = filter_mod.parse_filter_values(new_filters, state.static.filters)

        state = State.update(state, filter_values: parsed_filters)
        load_async(socket, state, page: 1, reset: true)
      end

      @doc """
      Apply new sort and reload.
      """
      @spec apply_sort(Phoenix.LiveView.Socket.t(), State.t(), atom()) ::
              Phoenix.LiveView.Socket.t()
      def apply_sort(socket, state, column) do
        sort_field_map = state.static.sort_field_map || %{}
        db_fields = Map.get(sort_field_map, column, [column])
        primary = List.first(db_fields) || column
        current_sorts = state.sort_fields
        existing_index = Enum.find_index(current_sorts, fn {f, _} -> f == primary end)

        new_sorts =
          case existing_index do
            nil ->
              Enum.map(db_fields, &{&1, :asc}) ++ current_sorts

            0 ->
              {_, current_order} = Enum.at(current_sorts, 0)

              case current_order do
                :asc -> toggle_sort_group(current_sorts, db_fields, :desc)
                :desc -> remove_sort_group(current_sorts, db_fields)
              end

            _index ->
              {_, current_order} = Enum.find(current_sorts, fn {f, _} -> f == primary end)
              new_order = if current_order == :asc, do: :desc, else: :asc
              rest = remove_sort_group(current_sorts, db_fields)
              Enum.map(db_fields, &{&1, new_order}) ++ rest
          end

        state = State.update(state, sort_fields: new_sorts)
        load_async(socket, state, page: 1, reset: true)
      end

      defp toggle_sort_group(sorts, db_fields, new_order) do
        Enum.map(sorts, fn {f, ord} ->
          if f in db_fields, do: {f, new_order}, else: {f, ord}
        end)
      end

      defp remove_sort_group(sorts, db_fields) do
        Enum.reject(sorts, fn {f, _} -> f in db_fields end)
      end

      @doc """
      Switch between active and archived records.
      """
      @spec apply_archive_status(Phoenix.LiveView.Socket.t(), State.t(), :active | :archived) ::
              Phoenix.LiveView.Socket.t()
      def apply_archive_status(socket, state, status) do
        current_status = state.archive_status

        if current_status == status do
          socket
        else
          current_mode_state = %{
            filter_values: state.filter_values,
            sort_fields: state.sort_fields,
            selected_ids: state.selected_ids,
            excluded_ids: state.excluded_ids,
            select_all?: state.select_all?
          }

          {saved_state_key, restore_state_key} =
            case current_status do
              :active -> {:saved_active_state, :saved_archived_state}
              :archived -> {:saved_archived_state, :saved_active_state}
            end

          saved_state = Map.get(state, restore_state_key) || default_mode_state()

          state =
            state
            |> State.update(
              archive_status: status,
              filter_values: saved_state.filter_values,
              sort_fields: saved_state.sort_fields,
              selected_ids: saved_state.selected_ids,
              excluded_ids: saved_state.excluded_ids,
              select_all?: saved_state.select_all?
            )
            |> Map.put(saved_state_key, current_mode_state)

          load_async(socket, state, page: 1, reset: true)
        end
      end

      @spec default_mode_state() :: map()
      defp default_mode_state do
        %{
          filter_values: %{},
          sort_fields: [],
          selected_ids: MapSet.new(),
          excluded_ids: MapSet.new(),
          select_all?: false
        }
      end

      @spec maybe_sync_url(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
      defp maybe_sync_url(socket, state) do
        if State.bidirectional_url_sync?(state) do
          path = build_sync_path(state)
          Phoenix.LiveView.push_patch(socket, to: path, replace: true)
        else
          socket
        end
      end

      @spec build_sync_path(State.t()) :: String.t()
      defp build_sync_path(state) do
        base_path = state.base_path || "/"
        UrlSync.build_path(base_path, state, state.static.url_sync_config)
      end

      @spec resolve_query_builder(module() | nil) :: module()
      defp resolve_query_builder(nil), do: query_builder()

      defp resolve_query_builder(resource) do
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config, :query, query_builder())
      end

      @spec resolve_filter_parser(module() | nil) :: module()
      defp resolve_filter_parser(nil), do: filter_parser()

      defp resolve_filter_parser(resource) do
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config, :filter_parser, filter_parser())
      end

      @spec resolve_pagination_handler(module() | nil) :: module()
      defp resolve_pagination_handler(nil), do: pagination_handler()

      defp resolve_pagination_handler(resource) do
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config, :pagination, pagination_handler())
      end

      @spec resolve_tenant_resolver(module() | nil) :: module()
      defp resolve_tenant_resolver(nil), do: tenant_resolver()

      defp resolve_tenant_resolver(resource) do
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config, :tenant, tenant_resolver())
      end

      @spec resolve_hook_runner(module() | nil) :: module()
      defp resolve_hook_runner(nil), do: hook_runner()

      defp resolve_hook_runner(resource) do
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config, :hooks, hook_runner())
      end

      @spec resolve_relation_loader(module() | nil) :: module()
      defp resolve_relation_loader(nil), do: relation_loader()

      defp resolve_relation_loader(resource) do
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config, :relation, relation_loader())
      end

      defoverridable query_builder: 0,
                     filter_parser: 0,
                     pagination_handler: 0,
                     tenant_resolver: 0,
                     hook_runner: 0,
                     relation_loader: 0,
                     maybe_load: 2,
                     load_async: 2,
                     load_async: 3,
                     handle_async: 3,
                     reload: 2,
                     load_more: 2,
                     apply_filters: 3,
                     apply_sort: 3,
                     apply_archive_status: 3
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader
end
