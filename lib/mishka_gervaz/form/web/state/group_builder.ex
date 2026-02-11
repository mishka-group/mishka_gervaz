defmodule MishkaGervaz.Form.Web.State.GroupBuilder do
  @moduledoc """
  Builds group layout configuration from DSL.

  Groups organize fields into visual sections. Each group has a list of
  field names and optional UI configuration (label, icon, collapsible).

  ## Overridable Functions

  - `build/2` - Build groups from config and resource
  - `assign_fields_to_groups/2` - Assign built fields to their groups

  ## User Override

      defmodule MyApp.Form.GroupBuilder do
        use MishkaGervaz.Form.Web.State.GroupBuilder

        def build(config, resource) do
          super(config, resource) |> Enum.reject(&(&1.name == :hidden_group))
        end
      end
  """

  alias MishkaGervaz.Resource.Info.Form, as: Info

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.State.Builder

      alias MishkaGervaz.Resource.Info.Form, as: Info

      import MishkaGervaz.Helpers, only: [get_ui_label: 1]

      @doc """
      Builds groups from config and resource.

      Returns a list of group config maps with resolved labels.
      """
      @spec build(map(), module()) :: list(map())
      def build(config, resource) when is_map(config) do
        Info.groups(resource)
        |> Enum.map(fn group ->
          label = get_ui_label(group)
          Map.put(group, :resolved_label, label)
        end)
      end

      @spec build(term(), term()) :: list()
      def build(_, _), do: []

      @doc """
      Assigns built field configs to their respective groups.

      Returns groups with a `:resolved_fields` key containing the
      actual field config maps (not just names).
      """
      @spec assign_fields_to_groups(list(map()), list(map())) :: list(map())
      def assign_fields_to_groups(groups, fields) do
        field_map = Map.new(fields, &{&1.name, &1})

        Enum.map(groups, fn group ->
          group_field_names = Map.get(group, :fields, [])

          resolved_fields =
            group_field_names
            |> Enum.map(&Map.get(field_map, &1))
            |> Enum.reject(&is_nil/1)

          Map.put(group, :resolved_fields, resolved_fields)
        end)
      end

      defoverridable build: 2, assign_fields_to_groups: 2
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.GroupBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.GroupBuilder
end
