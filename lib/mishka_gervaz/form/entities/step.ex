defmodule MishkaGervaz.Form.Entities.Step do
  @moduledoc """
  Entity struct for form wizard/tab step configuration.

  This module defines the struct and schema for steps, following Ash's
  entity pattern with `opt_schema` and `transform/1`.

  Steps reference groups (which in turn reference fields), creating
  the hierarchy: step -> groups -> fields.
  """

  @type t :: %__MODULE__{
          name: atom(),
          groups: [atom()],
          action: atom() | nil,
          visible: boolean() | (map() -> boolean()),
          summary: boolean(),
          on_enter: (map() -> map()) | nil,
          before_leave: (map() -> map()) | nil,
          after_leave: (map() -> map()) | nil,
          ui: __MODULE__.Ui.t() | nil,
          __identifier__: atom() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    :action,
    :on_enter,
    :before_leave,
    :after_leave,
    groups: [],
    visible: true,
    summary: false,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Step identifier."
    ],
    groups: [
      type: {:list, :atom},
      required: true,
      doc: "Group names belonging to this step."
    ],
    action: [
      type: :atom,
      doc: "Validation action to run when leaving this step."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Static or dynamic visibility."
    ],
    summary: [
      type: :boolean,
      default: false,
      doc: "Whether this step is a summary/review step."
    ],
    on_enter: [
      type: {:fun, 1},
      doc: "Callback invoked when entering the step. Receives state, returns state."
    ],
    before_leave: [
      type: {:fun, 1},
      doc: "Callback invoked before leaving the step. Return {:halt, state} to block navigation."
    ],
    after_leave: [
      type: {:fun, 1},
      doc: "Callback invoked after leaving the step. Receives state, returns state."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the step after DSL compilation.

  Extracts the nested ui entity from the list wrapper.
  """
  def transform(%__MODULE__{} = step) do
    {:ok, extract_ui(step)}
  end

  def transform(step), do: {:ok, step}

  defp extract_ui(%{ui: [ui | _]} = step), do: %{step | ui: ui}
  defp extract_ui(%{ui: ui} = step) when is_struct(ui), do: step
  defp extract_ui(step), do: step
end

defmodule MishkaGervaz.Form.Entities.Step.Ui do
  @moduledoc """
  UI/presentation configuration for a form step.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          icon: String.t() | nil,
          description: String.t() | nil,
          class: String.t() | nil,
          header_class: String.t() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            icon: nil,
            description: nil,
            class: nil,
            header_class: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Step label."
    ],
    icon: [
      type: :string,
      doc: "Step icon."
    ],
    description: [
      type: :string,
      doc: "Step description."
    ],
    class: [
      type: :string,
      doc: "Step CSS classes."
    ],
    header_class: [
      type: :string,
      doc: "Step header CSS classes."
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
