defmodule MishkaGervaz.Table.Web.State.ColumnBuilder do
  @moduledoc """
  Builds column configuration from DSL and resource attributes.

  ## Overridable Functions

  - `build/2` - Build columns from config and resource
  - `resolve_type/2` - Resolve column type module
  - `sort_by_order/2` - Sort columns by configured order

  ## User Override

      defmodule MyApp.Table.ColumnBuilder do
        use MishkaGervaz.Table.Web.State.ColumnBuilder

        def build(config, resource) do
          super(config, resource) ++ [custom_audit_column()]
        end
      end
  """

  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Table.Types.Column, as: ColumnType

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.State.Builder

      alias MishkaGervaz.Resource.Info.Table, as: Info
      alias MishkaGervaz.Table.Types.Column, as: ColumnType

      @doc """
      Builds columns from config and resource.

      ## Parameters

        - `config` - The table configuration map
        - `resource` - The Ash resource module

      ## Returns

        - A list of column maps with resolved types and attributes
      """
      @spec build(map(), module()) :: list(map())
      def build(config, resource) when is_map(config) do
        columns_config = Map.get(config, :columns, %{})
        column_order = Map.get(columns_config, :order, [])
        attributes = get_resource_attributes(resource)

        columns =
          Info.columns(resource)
          |> Enum.map(fn col ->
            col
            |> maybe_resolve_type(attributes)
            |> Map.put(:attribute, Map.get(attributes, col.name))
          end)

        if column_order != [], do: sort_by_order(columns, column_order), else: columns
      end

      @spec build(term(), term()) :: list()
      def build(_, _), do: []

      @doc """
      Resolves the type module for a column based on its attributes.

      ## Parameters

        - `column` - The column map
        - `attributes` - Map of resource attributes keyed by name

      ## Returns

        - The resolved type module
      """
      @spec resolve_type(map(), map()) :: module()
      def resolve_type(column, attributes) do
        ColumnType.resolve_type(column, attributes)
      end

      @doc """
      Sorts columns by the specified order.

      ## Parameters

        - `columns` - List of column maps
        - `order` - List of column names in desired order

      ## Returns

        - Sorted list of columns, with ordered columns first, then unordered
      """
      @spec sort_by_order(list(map()), list(atom())) :: list(map())
      def sort_by_order(columns, order) do
        {ordered, unordered} = Enum.split_with(columns, &(&1.name in order))

        sorted =
          Enum.sort_by(ordered, fn col ->
            Enum.find_index(order, &(&1 == col.name)) || 999
          end)

        sorted ++ unordered
      end

      @spec maybe_resolve_type(map(), map()) :: map()
      defp maybe_resolve_type(%{type_module: nil} = col, attributes) do
        Map.put(col, :type_module, resolve_type(col, attributes))
      end

      @spec maybe_resolve_type(map(), map()) :: map()
      defp maybe_resolve_type(col, _attributes), do: col

      @spec get_resource_attributes(module()) :: map()
      defp get_resource_attributes(resource) do
        resource
        |> Ash.Resource.Info.attributes()
        |> Map.new(&{&1.name, &1})
      end

      defoverridable build: 2, resolve_type: 2, sort_by_order: 2
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.ColumnBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.ColumnBuilder
end
