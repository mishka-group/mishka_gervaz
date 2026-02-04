defmodule MishkaGervaz.Table.Web.DataLoader.QueryBuilder do
  @moduledoc """
  Builds Ash queries with filters and sorting from table state.

  ## Overridable Functions

  - `build_query/1` - Build complete query from state
  - `apply_filters_to_query/4` - Apply filter values to query with state context
  - `apply_sorting_to_query/2` - Apply sort fields to query
  - `apply_default_filter/3` - Apply filter when no type_module is configured
  - `build_apply_context/1` - Build context map passed to `apply` functions

  ## User Override

      defmodule MyApp.Table.DataLoader.QueryBuilder do
        use MishkaGervaz.Table.Web.DataLoader.QueryBuilder

        def apply_default_filter(query, field, value) when is_binary(value) do
          Ash.Query.filter(query, ^ref(field) == ^value)
        end
      end
  """

  alias MishkaGervaz.Table.Web.State

  require Ash.Query

  import Ash.Expr

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.DataLoader.Builder

      alias MishkaGervaz.Table.Web.State

      require Ash.Query

      import Ash.Expr

      @doc """
      Build query from state with filters, sorting, and preloads.
      """
      @spec build_query(State.t()) :: Ash.Query.t()
      def build_query(state) do
        %State{
          static: %{resource: resource, filters: filter_configs},
          filter_values: filter_values,
          sort_fields: sort_fields,
          path_params: path_params
        } = state

        preloads = State.get_preloads(state)

        resource
        |> Ash.Query.new()
        |> apply_path_params(path_params || %{}, resource)
        |> apply_filters_to_query(filter_values, filter_configs, state)
        |> apply_sorting_to_query(sort_fields)
        |> Ash.Query.load(preloads)
      end

      @doc """
      Apply filter values to query using filter type modules.

      When a filter has an `apply` function, it receives a context map built
      from `state` containing `path_params`, `current_user`, `master_user?`,
      `filter_values`, and `archive_status`.
      """
      @spec apply_filters_to_query(Ash.Query.t(), map(), list(), State.t() | nil) :: Ash.Query.t()
      def apply_filters_to_query(query, filter_values, _filter_configs, _state)
          when map_size(filter_values) == 0 do
        query
      end

      def apply_filters_to_query(query, filter_values, filter_configs, state) do
        context = build_apply_context(state)

        Enum.reduce(filter_values, query, fn {field, value}, acc ->
          filter_config = Enum.find(filter_configs, &(&1.name == field))

          cond do
            filter_config && filter_config.apply ->
              parsed_value =
                if filter_config.type_module do
                  filter_config.type_module.parse_value(value, filter_config)
                else
                  value
                end

              if parsed_value != nil and parsed_value != "" do
                filter_config.apply.(acc, parsed_value, context)
              else
                acc
              end

            filter_config && filter_config.type_module ->
              parsed_value = filter_config.type_module.parse_value(value, filter_config)
              query_field = Map.get(filter_config, :source) || field

              filter_config.type_module.build_query(acc, query_field, parsed_value, filter_config)

            true ->
              apply_default_filter(acc, field, value)
          end
        end)
      end

      @doc """
      Build context map passed as third argument to `apply` functions.

      Provides the apply function with path_params, current_user, master_user?,
      filter_values, and archive_status from the current state.
      """
      @spec build_apply_context(State.t() | nil) :: map()
      def build_apply_context(nil), do: %{}

      def build_apply_context(%State{} = state) do
        %{
          path_params: state.path_params || %{},
          current_user: state.current_user,
          master_user?: state.master_user?,
          filter_values: state.filter_values,
          archive_status: state.archive_status
        }
      end

      def build_apply_context(_), do: %{}

      @doc """
      Apply sort fields to query.
      """
      @spec apply_sorting_to_query(Ash.Query.t(), list()) :: Ash.Query.t()
      def apply_sorting_to_query(query, []), do: query

      def apply_sorting_to_query(query, sort_fields) do
        Ash.Query.sort(query, sort_fields)
      end

      @doc """
      Apply path params as permanent (non-clearable) query filters.
      Only applies when the param name matches an actual attribute on the resource.
      """
      @spec apply_path_params(Ash.Query.t(), map(), module()) :: Ash.Query.t()
      def apply_path_params(query, path_params, _resource) when map_size(path_params) == 0,
        do: query

      def apply_path_params(query, path_params, resource) do
        attribute_names =
          resource
          |> Ash.Resource.Info.attributes()
          |> MapSet.new(& &1.name)

        Enum.reduce(path_params, query, fn {param_name, value}, acc ->
          if MapSet.member?(attribute_names, param_name) do
            Ash.Query.filter(acc, ^ref(param_name) == ^value)
          else
            acc
          end
        end)
      end

      @doc """
      Apply default filter behavior when no type_module is configured.
      Uses ilike for strings, exact match for other types.
      """
      @spec apply_default_filter(Ash.Query.t(), atom(), any()) :: Ash.Query.t()
      def apply_default_filter(query, field, value) when is_binary(value) do
        Ash.Query.filter(query, ilike(^ref(field), ^"%#{value}%"))
      end

      def apply_default_filter(query, field, value) do
        Ash.Query.filter(query, ^ref(field) == ^value)
      end

      defoverridable build_query: 1,
                     apply_path_params: 3,
                     apply_filters_to_query: 4,
                     apply_sorting_to_query: 2,
                     apply_default_filter: 3,
                     build_apply_context: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.QueryBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.QueryBuilder
end
