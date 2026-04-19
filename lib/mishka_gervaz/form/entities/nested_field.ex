defmodule MishkaGervaz.Form.Entities.NestedField do
  @moduledoc """
  Entity struct for nested/embedded sub-field configuration.

  Defines the schema for individual fields within a `:nested` form field,
  allowing per-sub-field type overrides, visibility, and UI customization.
  """

  @builtin_field_types [
    :text,
    :textarea,
    :number,
    :checkbox,
    :date,
    :datetime,
    :select,
    :hidden,
    :toggle,
    :range,
    :json
  ]

  @type position :: integer() | :first | :last | {:before, atom()} | {:after, atom()}

  @type t :: %__MODULE__{
          name: atom(),
          type: atom() | nil,
          required: boolean() | nil,
          visible: boolean(),
          readonly: boolean(),
          default: any(),
          options: list() | nil,
          position: position() | nil,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    type: nil,
    required: nil,
    visible: true,
    readonly: false,
    default: nil,
    options: nil,
    position: nil,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Sub-field name. Must match an attribute on the embedded resource."
    ],
    type: [
      type: {:in, [nil | @builtin_field_types]},
      default: nil,
      doc: "Sub-field type. Nil for auto-detection from embedded attribute."
    ],
    required: [
      type: :boolean,
      doc: "Override required. Nil to auto-detect from `allow_nil?`."
    ],
    visible: [
      type: :boolean,
      default: true,
      doc: "Whether this sub-field is visible."
    ],
    readonly: [
      type: :boolean,
      default: false,
      doc: "Render as read-only."
    ],
    default: [
      type: :any,
      doc: "Default value for this sub-field."
    ],
    options: [
      type: {:list, :any},
      doc: "Options for select-type sub-fields."
    ],
    position: [
      type: :any,
      doc:
        "Position in the nested field list (integer, :first, :last, {:before, :field}, {:after, :field})."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(%__MODULE__{} = nested_field) do
    {:ok, extract_ui(nested_field)}
  end

  def transform(nested_field), do: {:ok, nested_field}

  defp extract_ui(%{ui: [ui | _]} = nf), do: %{nf | ui: ui}
  defp extract_ui(%{ui: ui} = nf) when is_struct(ui), do: nf
  defp extract_ui(%{ui: []} = nf), do: %{nf | ui: nil}
  defp extract_ui(nf), do: nf
end

defmodule MishkaGervaz.Form.Entities.NestedField.Ui do
  @moduledoc """
  UI/presentation configuration for a nested sub-field.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          placeholder: String.t() | nil,
          description: String.t() | nil,
          class: String.t() | nil,
          rows: integer() | nil,
          span: pos_integer() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            placeholder: nil,
            description: nil,
            class: nil,
            rows: nil,
            span: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Sub-field label. String or `fn -> gettext(...) end`."
    ],
    placeholder: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Placeholder text. String or `fn -> gettext(...) end` for i18n."
    ],
    description: [
      type: :string,
      doc: "Help text."
    ],
    class: [
      type: :string,
      doc: "CSS classes for this sub-field input."
    ],
    rows: [
      type: :integer,
      doc: "Number of rows for textarea sub-fields."
    ],
    span: [
      type: :pos_integer,
      doc: "Grid column span (1-2)."
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
