defmodule MishkaGervaz.Table.Web.DataLoader.Builder do
  @moduledoc """
  Common macro for all DataLoader sub-builders.

  Provides consistent structure and defoverridable pattern for:
  - QueryBuilder
  - FilterParser
  - PaginationHandler
  - TenantResolver
  - HookRunner

  ## Usage

      defmodule MishkaGervaz.Table.Web.DataLoader.QueryBuilder do
        use MishkaGervaz.Table.Web.DataLoader.Builder

        def build_query(state) do
          # implementation
        end
      end

  ## User Override

      defmodule MyApp.Table.DataLoader.QueryBuilder do
        use MishkaGervaz.Table.Web.DataLoader.QueryBuilder

        def apply_filters_to_query(query, filter_values, filter_configs, state) do
          super(query, filter_values, filter_configs, state)
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      @spec __builder_info__(:module) :: module()
      def __builder_info__(:module), do: __MODULE__
    end
  end
end
