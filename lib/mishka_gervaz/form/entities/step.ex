defmodule MishkaGervaz.Form.Entities.Step do
  @moduledoc """
  Wizard / tabs step — a named bundle of groups with optional
  navigation guards.

  Steps reference groups (which in turn reference fields), so the form
  hierarchy reads `step → groups → fields`. Steps appear inside the
  layout block when `mode: :wizard` or `mode: :tabs`. They support
  `on_enter` / `before_leave` / `after_leave` lifecycle callbacks (where
  `before_leave` can return `{:halt, state}` to block navigation), an
  optional `action` for inline validation, a `summary` flag for
  read-only review steps, and a `save` flag for a step whose Next saves.

  ## A step that saves

  `save true` makes Next on the step save what the form holds, as the last step's submit does:
  the first such save creates the record, the later ones update it. Once the step's own fields
  hold no error the save runs; a save the action refuses stays on the step with its errors, or
  moves to the earlier step holding one. A save that succeeds sends the page
  `{:form_saved, mode, record}` and opens the saved record for editing on the next step, so a
  reader who leaves the form half way keeps a draft. A page that passes `record_id` sets it to the
  saved record's id when it hears `{:form_saved, :create, record}`, or a later render of the page
  takes the form back to create. On free tabs every save saves already and the flag changes
  nothing; on the last step it is the save the step makes anyway. A `confirm` question on the
  submit block's `create` or `update` button is asked by the last step's save only.

  ## Example

      layout do
        mode :wizard
        navigation :sequential
        persistence :ets

        step :details do
          groups [:basic, :meta]
          action :validate_details
          save true

          on_enter fn state -> state end
          before_leave fn state -> state end

          ui do
            label "Details"
            icon "hero-information-circle"
          end
        end

        step :review do
          groups [:flags]
          summary true
        end
      end

  See `MishkaGervaz.Form.Dsl.Layout` for the surrounding section and
  `MishkaGervaz.Form.Entities.Step.Ui` for the `ui` sub-entity.
  """

  @type t :: %__MODULE__{
          name: atom(),
          groups: [atom()],
          action: atom() | nil,
          summary: boolean(),
          save: boolean(),
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
    summary: false,
    save: false,
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
    summary: [
      type: :boolean,
      default: false,
      doc: "Whether this step is a summary/review step."
    ],
    save: [
      type: :boolean,
      default: false,
      doc:
        "Whether Next on this step saves what the form holds, a create first and an update after, then opens the saved record on the next step."
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
  Transform the step after DSL compilation. Unwraps the singleton `ui`
  sub-entity from the parser's list wrapper.
  """
  def transform(%__MODULE__{} = step) do
    {:ok, MishkaGervaz.Helpers.extract_singleton_entity(step, :ui)}
  end

  def transform(step), do: {:ok, step}
end

defmodule MishkaGervaz.Form.Entities.Step.Ui do
  @moduledoc """
  UI/presentation configuration for a `MishkaGervaz.Form.Entities.Step`
  — label, icon, description, and step-container CSS classes.
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

  @doc false
  def transform(ui), do: {:ok, ui}
end
