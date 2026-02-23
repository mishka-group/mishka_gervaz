defmodule MishkaGervaz.Form.Entities.AutoFields do
  @moduledoc """
  Configuration for auto-discovering fields from Ash resource attributes.
  """

  @type t :: %__MODULE__{
          except: [atom()],
          only: [atom()] | nil,
          position: :start | :end,
          defaults: __MODULE__.Defaults.t() | nil,
          ui_defaults: __MODULE__.UiDefaults.t() | nil,
          overrides: [__MODULE__.Override.t()],
          __spark_metadata__: map() | nil
        }

  defstruct except: [],
            only: nil,
            position: :end,
            defaults: nil,
            ui_defaults: nil,
            overrides: [],
            __spark_metadata__: nil

  @opt_schema [
    except: [
      type: {:list, :atom},
      default: [],
      doc: "Exclude these attributes."
    ],
    only: [
      type: {:list, :atom},
      doc: "Only these attributes (overrides except)."
    ],
    position: [
      type: {:in, [:start, :end]},
      default: :end,
      doc: "Where to place auto fields."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(auto_fields), do: {:ok, auto_fields}
end

defmodule MishkaGervaz.Form.Entities.AutoFields.Defaults do
  @moduledoc """
  Default options for auto-discovered fields.
  """

  @type t :: %__MODULE__{
          required: boolean(),
          visible: boolean(),
          readonly: boolean(),
          __spark_metadata__: map() | nil
        }

  defstruct required: false,
            visible: true,
            readonly: false,
            __spark_metadata__: nil

  @opt_schema [
    required: [
      type: :boolean,
      default: false,
      doc: "Default required value."
    ],
    visible: [
      type: :boolean,
      default: true,
      doc: "Default visible value."
    ],
    readonly: [
      type: :boolean,
      default: false,
      doc: "Default readonly value."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(defaults), do: {:ok, defaults}
end

defmodule MishkaGervaz.Form.Entities.AutoFields.UiDefaults do
  @moduledoc """
  Default UI options for auto-discovered fields.
  """

  @type t :: %__MODULE__{
          boolean_widget: :checkbox | :toggle | :select,
          textarea_threshold: integer(),
          number_step: integer(),
          select_prompt: String.t(),
          datetime_format: atom(),
          __spark_metadata__: map() | nil
        }

  defstruct boolean_widget: :checkbox,
            textarea_threshold: 255,
            number_step: 1,
            select_prompt: "Select...",
            datetime_format: :medium,
            __spark_metadata__: nil

  @opt_schema [
    boolean_widget: [
      type: {:in, [:checkbox, :toggle, :select]},
      default: :checkbox,
      doc: "Widget for boolean fields."
    ],
    textarea_threshold: [
      type: :integer,
      default: 255,
      doc: "Max length above which string becomes textarea."
    ],
    number_step: [
      type: :integer,
      default: 1,
      doc: "Default step for number inputs."
    ],
    select_prompt: [
      type: :string,
      default: "Select...",
      doc: "Default select prompt text."
    ],
    datetime_format: [
      type: :atom,
      default: :medium,
      doc: "Default datetime display format."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui_defaults), do: {:ok, ui_defaults}
end

defmodule MishkaGervaz.Form.Entities.AutoFields.Override do
  @moduledoc """
  Override configuration for a specific auto-discovered field.
  """

  @builtin_field_types [
    :text,
    :textarea,
    :number,
    :checkbox,
    :date,
    :datetime,
    :select,
    :multi_select,
    :relation,
    :json,
    :nested,
    :array_of_maps,
    :string_list,
    :file,
    :hidden,
    :toggle,
    :range
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: atom() | nil,
          required: boolean() | nil,
          visible: boolean() | nil,
          readonly: boolean() | nil,
          format: (any() -> any()) | (map(), map(), any() -> any()) | nil,
          ui: MishkaGervaz.Form.Entities.Field.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    type: nil,
    required: nil,
    visible: nil,
    readonly: nil,
    format: nil,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Field name to override."
    ],
    type: [
      type:
        {:or, [{:in, @builtin_field_types}, {:behaviour, MishkaGervaz.Form.Behaviours.FieldType}]},
      doc: "Override detected type."
    ],
    required: [
      type: :boolean,
      doc: "Override required."
    ],
    visible: [
      type: :boolean,
      doc: "Override visible."
    ],
    readonly: [
      type: :boolean,
      doc: "Override readonly."
    ],
    format: [
      type: {:or, [{:fun, 1}, {:fun, 3}]},
      doc: "Value formatter."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(%__MODULE__{} = override) do
    {:ok, extract_ui(override)}
  end

  def transform(override), do: {:ok, override}

  defp extract_ui(%{ui: [ui | _]} = override), do: %{override | ui: ui}
  defp extract_ui(%{ui: ui} = override) when is_struct(ui), do: override
  defp extract_ui(override), do: override
end
