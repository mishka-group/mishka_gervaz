defmodule MishkaGervaz.Form.Entities.Group do
  @moduledoc """
  Form field group — bundles fields into a named, layout-aware unit.

  A group references field names by atom; the surrounding layout (and
  any wizard/tabs `step`) arranges the fields inside each group. Groups
  carry the standard `visible` / `restricted` access predicates and an
  optional `ui` sub-entity for label, icon, description, and CSS
  classes.

  ## Example

      groups do
        group :general do
          fields [:title, :content, :status]
          collapsible true
          collapsed false

          ui do
            label "General"
            icon "hero-pencil"
            class "border p-4"
          end
        end
      end

  See `MishkaGervaz.Form.Dsl.Groups` for the DSL section that exposes
  this entity, and `MishkaGervaz.Form.Entities.Group.Ui` for the `ui`
  sub-entity.
  """

  alias MishkaGervaz.Form.Entities.Schema

  @type t :: %__MODULE__{
          name: atom(),
          fields: [atom()],
          collapsed: boolean(),
          collapsible: boolean(),
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          position: integer() | :first | :last | nil,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    fields: [],
    collapsed: false,
    collapsible: false,
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
                fields: [
                  type: {:list, :atom},
                  required: true,
                  doc: "Field names belonging to this group."
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
                position: [
                  type: :any,
                  doc: "Group position (integer, :first, :last)."
                ]
              ] ++ Schema.access_predicates()

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the group after DSL compilation. Unwraps the singleton `ui`
  sub-entity from the parser's list wrapper.
  """
  def transform(%__MODULE__{} = group) do
    {:ok, MishkaGervaz.Helpers.extract_singleton_entity(group, :ui)}
  end

  def transform(group), do: {:ok, group}
end

defmodule MishkaGervaz.Form.Entities.Group.Ui do
  @moduledoc """
  UI/presentation configuration for a `MishkaGervaz.Form.Entities.Group`
  — label, icon, description, container classes, and a per-group columns
  override.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          icon: String.t() | nil,
          description: String.t() | nil,
          class: String.t() | nil,
          header_class: String.t() | nil,
          columns: 1 | 2 | 3 | 4 | nil,
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
      type: {:in, [1, 2, 3, 4]},
      doc: "Number of grid columns for this group (overrides global layout columns)."
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
