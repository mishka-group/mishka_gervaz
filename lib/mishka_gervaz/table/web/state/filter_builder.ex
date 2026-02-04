defmodule MishkaGervaz.Table.Web.State.FilterBuilder do
  @moduledoc """
  Builds filter configuration from DSL and resource attributes.

  ## Overridable Functions

  - `build/3` - Build filters from config, resource, and user
  - `build_initial_values/1` - Build initial filter values from defaults
  - `resolve_type/1` - Resolve filter type module
  - `load_relationship_options/2` - Load options for relationship filters

  ## User Override

      defmodule MyApp.Table.FilterBuilder do
        use MishkaGervaz.Table.Web.State.FilterBuilder

        def build(config, resource, user) do
          super(config, resource, user)
          |> Enum.reject(&(&1.name == :internal_field))
        end
      end
  """

  alias MishkaGervaz.Table.Types.Filter, as: FilterType

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.State.Builder

      alias MishkaGervaz.Table.Types.Filter, as: FilterType

      @doc """
      Builds filters from config, resource, and current user.

      ## Parameters

        - `config` - The table configuration map
        - `resource` - The Ash resource module
        - `current_user` - The current user for loading relationship options

      ## Returns

        - A list of filter maps with resolved types, attributes, and options
      """
      @spec build(map(), module(), map() | nil) :: list(map())
      def build(config, resource, current_user) when is_map(config) do
        filters_config = Map.get(config, :filters, %{})
        attributes = get_resource_attributes(resource)
        calculations = get_resource_calculations(resource)
        relationships = get_resource_relationships(resource)

        Enum.map(Map.get(filters_config, :list, []), fn filter ->
          filter
          |> maybe_resolve_type()
          |> maybe_resolve_options()
          |> Map.put(:attribute, Map.get(attributes, filter.name))
          |> Map.put(:calculation, Map.get(calculations, filter.name))
          |> maybe_load_relationship_options(relationships, current_user)
        end)
      end

      @spec build(term(), term(), term()) :: list()
      def build(_, _, _), do: []

      @doc """
      Builds initial filter values from filter defaults.

      ## Parameters

        - `filters` - List of filter maps

      ## Returns

        - A map of filter names to their default values
      """
      @spec build_initial_values(list(map())) :: map()
      def build_initial_values(filters) do
        filters
        |> Enum.filter(&(Map.get(&1, :default) != nil))
        |> Map.new(&{&1.name, &1.default})
      end

      @doc """
      Resolves the type module for a filter.

      ## Parameters

        - `filter` - The filter map

      ## Returns

        - The resolved type module
      """
      @spec resolve_type(map()) :: module()
      def resolve_type(filter) do
        FilterType.resolve_type(filter)
      end

      @doc """
      Loads options for relationship filters.

      ## Parameters

        - `relationship` - The Ash relationship struct
        - `current_user` - The current user for authorization

      ## Returns

        - A list of {label, value} tuples for select options
      """
      @spec load_relationship_options(struct(), map() | nil) :: list({binary(), term()})
      def load_relationship_options(relationship, current_user) do
        dest = relationship.destination
        display_field = find_display_field(dest)

        case Ash.read(dest, actor: current_user, authorize?: false, page: false) do
          {:ok, records} ->
            options =
              Enum.map(records, fn record ->
                {to_string(Map.get(record, display_field, record.id)), record.id}
              end)

            if relationship.allow_nil?, do: [{"All", ""} | options], else: options

          {:error, _} ->
            []
        end
      end

      @spec maybe_resolve_type(map()) :: map()
      defp maybe_resolve_type(%{type_module: nil} = filter) do
        Map.put(filter, :type_module, resolve_type(filter))
      end

      @spec maybe_resolve_type(map()) :: map()
      defp maybe_resolve_type(filter), do: filter

      @spec maybe_resolve_options(map()) :: map()
      defp maybe_resolve_options(%{options: options} = filter) when is_function(options, 0) do
        Map.put(filter, :options, options.())
      end

      defp maybe_resolve_options(filter), do: filter

      @spec maybe_load_relationship_options(map(), list(struct()), map() | nil) :: map()
      defp maybe_load_relationship_options(filter, relationships, current_user) do
        rel =
          Enum.find(relationships, fn r ->
            r.type == :belongs_to and r.source_attribute == filter.name
          end)

        if rel && is_nil(filter[:options]) do
          options = load_relationship_options(rel, current_user)
          Map.put(filter, :options, options)
        else
          filter
        end
      end

      @spec get_resource_attributes(module()) :: map()
      defp get_resource_attributes(resource) do
        resource
        |> Ash.Resource.Info.attributes()
        |> Map.new(&{&1.name, &1})
      end

      @spec get_resource_calculations(module()) :: map()
      defp get_resource_calculations(resource) do
        resource
        |> Ash.Resource.Info.calculations()
        |> Map.new(&{&1.name, &1})
      end

      @spec get_resource_relationships(module()) :: list(struct())
      defp get_resource_relationships(resource) do
        Ash.Resource.Info.relationships(resource)
      end

      @spec find_display_field(module()) :: atom()
      defp find_display_field(resource) do
        attrs = Ash.Resource.Info.attributes(resource)

        Enum.find_value([:name, :title, :label], :id, fn field ->
          if Enum.any?(attrs, &(&1.name == field)), do: field
        end)
      end

      defoverridable build: 3,
                     build_initial_values: 1,
                     resolve_type: 1,
                     load_relationship_options: 2
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.FilterBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.FilterBuilder
end
