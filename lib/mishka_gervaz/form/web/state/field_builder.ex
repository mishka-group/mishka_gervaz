defmodule MishkaGervaz.Form.Web.State.FieldBuilder do
  @moduledoc """
  Builds field configuration from DSL and resource attributes.

  ## Overridable Functions

  - `build/2` - Build fields from config and resource
  - `resolve_type/2` - Resolve field type module
  - `sort_by_order/2` - Sort fields by configured order
  - `build_field_config/3` - Build a single field's config map

  ## User Override

      defmodule MyApp.Form.FieldBuilder do
        use MishkaGervaz.Form.Web.State.FieldBuilder

        def build(config, resource) do
          super(config, resource) |> Enum.reject(&(&1.name == :hidden_field))
        end
      end
  """

  alias MishkaGervaz.Resource.Info.Form, as: Info

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.State.Builder

      alias MishkaGervaz.Resource.Info.Form, as: Info

      import MishkaGervaz.Helpers, only: [humanize: 1, get_ui_label: 1]

      @doc """
      Builds fields from config and resource.

      Returns a list of field config maps with resolved types, labels,
      and attribute metadata merged in.
      """
      @spec build(map(), module()) :: list(map())
      def build(config, resource) when is_map(config) do
        fields = Info.fields(resource)
        field_order = Info.field_order(resource)
        attributes = get_resource_attributes(resource)

        built =
          Enum.map(fields, fn field ->
            build_field_config(field, attributes, config)
          end)

        if field_order != [], do: sort_by_order(built, field_order), else: built
      end

      @spec build(term(), term()) :: list()
      def build(_, _), do: []

      @doc """
      Resolves the field type module for rendering.

      Maps DSL field types to their corresponding type modules.
      """
      @spec resolve_type(map(), map()) :: atom()
      def resolve_type(field, _attributes) do
        field[:type] || :text
      end

      @doc """
      Sorts fields by the specified order.

      Fields listed in `order` come first in their specified order,
      followed by any remaining fields.
      """
      @spec sort_by_order(list(map()), list(atom())) :: list(map())
      def sort_by_order(fields, order) do
        {ordered, unordered} = Enum.split_with(fields, &(&1.name in order))

        sorted =
          Enum.sort_by(ordered, fn field ->
            Enum.find_index(order, &(&1 == field.name)) || 999
          end)

        sorted ++ unordered
      end

      @doc """
      Builds a single field's configuration map.

      Merges DSL field config with resource attribute metadata.
      """
      @spec build_field_config(map(), map(), map()) :: map()
      def build_field_config(field, attributes, _config) do
        attr = Map.get(attributes, field.name)
        label = get_ui_label(field)

        field
        |> Map.put(:attribute, attr)
        |> Map.put(:resolved_label, label)
        |> Map.put(:resolved_type, resolve_type(field, attributes))
      end

      @spec get_resource_attributes(module()) :: map()
      defp get_resource_attributes(resource) do
        resource
        |> Ash.Resource.Info.attributes()
        |> Map.new(&{&1.name, &1})
      end

      defoverridable build: 2, resolve_type: 2, sort_by_order: 2, build_field_config: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.FieldBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.FieldBuilder
end
