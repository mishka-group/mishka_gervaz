defmodule MishkaGervaz.Table.Entities.FilterGroup do
  @moduledoc """
  Entity struct for table filter group configuration.

  Groups organize filters into collapsible sections within the filter layout.
  Follows the same pattern as `MishkaGervaz.Form.Entities.Group`.

  ## Example

      filter_groups do
        group :primary do
          filters [:search]
          collapsible false
        end

        group :advanced do
          filters [:status, :issue_type, :site_id]
          collapsible true
          collapsed true
          columns 3

          ui do
            label fn -> dgettext("mishka_gervaz", "Advanced Search") end
            icon "hero-funnel"
          end
        end
      end
  """

  @type t :: %__MODULE__{
          name: atom(),
          filters: [atom()],
          collapsed: boolean(),
          collapsible: boolean(),
          columns: 1 | 2 | 3 | 4 | 5 | 6 | nil,
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          position: integer() | :first | :last | nil,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    filters: [],
    collapsed: false,
    collapsible: false,
    columns: nil,
    visible: true,
    restricted: false,
    position: nil,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Group identifier."
    ],
    filters: [
      type: {:list, :atom},
      required: true,
      doc: "Filter names belonging to this group."
    ],
    collapsed: [
      type: :boolean,
      default: false,
      doc: "Start collapsed."
    ],
    collapsible: [
      type: :boolean,
      default: false,
      doc: "Can be collapsed by user."
    ],
    columns: [
      type: {:in, [1, 2, 3, 4, 5, 6]},
      doc: "Grid columns for this group's filters."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Static or dynamic visibility."
    ],
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Restrict to master users."
    ],
    position: [
      type: :any,
      doc: "Group position (integer, :first, :last)."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the group after DSL compilation.
  """
  def transform(%__MODULE__{} = group) do
    {:ok, extract_ui(group)}
  end

  def transform(group), do: {:ok, group}

  defp extract_ui(%{ui: [ui | _]} = group), do: %{group | ui: ui}
  defp extract_ui(%{ui: ui} = group) when is_struct(ui), do: group
  defp extract_ui(group), do: group
end

defmodule MishkaGervaz.Table.Entities.FilterGroup.Ui do
  @moduledoc """
  UI/presentation configuration for a filter group.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          icon: String.t() | nil,
          description: String.t() | nil,
          class: String.t() | nil,
          header_class: String.t() | nil,
          columns: 1 | 2 | 3 | 4 | 5 | 6 | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            icon: nil,
            description: nil,
            class: nil,
            header_class: nil,
            columns: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Group label."
    ],
    icon: [
      type: :string,
      doc: "Group icon."
    ],
    description: [
      type: :string,
      doc: "Group description."
    ],
    class: [
      type: :string,
      doc: "Group CSS classes."
    ],
    header_class: [
      type: :string,
      doc: "Group header CSS classes."
    ],
    columns: [
      type: {:in, [1, 2, 3, 4, 5, 6]},
      doc: "Number of grid columns for this group (overrides layout columns)."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end
