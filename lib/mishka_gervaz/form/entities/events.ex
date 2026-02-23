defmodule MishkaGervaz.Form.Entities.Events do
  @moduledoc """
  Entity struct for form events configuration.

  Allows overriding event handling modules at DSL level.

  ## Usage

  Override entire events module (positional argument):

      events MyApp.Form.CustomEvents

  Override specific sub-builders (block syntax):

      events do
        sanitization MyApp.Form.Events.SanitizationHandler
        validation MyApp.Form.Events.ValidationHandler
        submit MyApp.Form.Events.SubmitHandler
        step MyApp.Form.Events.StepHandler
        upload MyApp.Form.Events.UploadHandler
        relation MyApp.Form.Events.RelationHandler
        hooks MyApp.Form.Events.HookRunner
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `sanitization` - `MishkaGervaz.Form.Web.Events.SanitizationHandler.Default`
  - `validation` - `MishkaGervaz.Form.Web.Events.ValidationHandler.Default`
  - `submit` - `MishkaGervaz.Form.Web.Events.SubmitHandler.Default`
  - `step` - `MishkaGervaz.Form.Web.Events.StepHandler.Default`
  - `upload` - `MishkaGervaz.Form.Web.Events.UploadHandler.Default`
  - `relation` - `MishkaGervaz.Form.Web.Events.RelationHandler.Default`
  - `hooks` - `MishkaGervaz.Form.Web.Events.HookRunner.Default`
  """

  @type t :: %__MODULE__{
          module: module() | nil,
          sanitization: module() | nil,
          validation: module() | nil,
          submit: module() | nil,
          step: module() | nil,
          upload: module() | nil,
          relation: module() | nil,
          hooks: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct module: nil,
            sanitization: nil,
            validation: nil,
            submit: nil,
            step: nil,
            upload: nil,
            relation: nil,
            hooks: nil,
            __spark_metadata__: nil

  @opt_schema [
    module: [
      type: :atom,
      doc: """
      Override the entire events module. When set, all other options are ignored.
      The module must `use MishkaGervaz.Form.Web.Events`.
      """
    ],
    sanitization: [
      type: :atom,
      doc: """
      Sanitization handler module. Must `use MishkaGervaz.Form.Web.Events.SanitizationHandler`.
      Handles input sanitization to prevent XSS.
      """
    ],
    validation: [
      type: :atom,
      doc: """
      Validation handler module. Must `use MishkaGervaz.Form.Web.Events.ValidationHandler`.
      Handles phx-change form validation.
      """
    ],
    submit: [
      type: :atom,
      doc: """
      Submit handler module. Must `use MishkaGervaz.Form.Web.Events.SubmitHandler`.
      Handles phx-submit form creation and updates.
      """
    ],
    step: [
      type: :atom,
      doc: """
      Step handler module. Must `use MishkaGervaz.Form.Web.Events.StepHandler`.
      Handles wizard step navigation (next, prev, goto).
      """
    ],
    upload: [
      type: :atom,
      doc: """
      Upload handler module. Must `use MishkaGervaz.Form.Web.Events.UploadHandler`.
      Handles file upload events.
      """
    ],
    relation: [
      type: :atom,
      doc: """
      Relation handler module. Must `use MishkaGervaz.Form.Web.Events.RelationHandler`.
      Handles relation field search/select/clear events.
      """
    ],
    hooks: [
      type: :atom,
      doc: """
      Hook runner module. Must `use MishkaGervaz.Form.Web.Events.HookRunner`.
      Executes hooks during event handling.
      """
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the events after DSL compilation.
  """
  def transform(%__MODULE__{} = events) do
    {:ok, events}
  end

  def transform(events), do: {:ok, events}
end
