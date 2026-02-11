defmodule MishkaGervaz.Form.Dsl.State do
  @moduledoc """
  State section DSL definition for form configuration.

  Allows overriding state management modules at DSL level.

  ## Usage

  Override specific sub-builders:

      mishka_gervaz do
        form do
          state do
            field MyApp.Form.FieldBuilder
            group MyApp.Form.GroupBuilder
            step MyApp.Form.StepBuilder
            presentation MyApp.Form.Presentation
            access MyApp.Form.Access
          end
        end
      end

  Or override the entire state module:

      mishka_gervaz do
        form do
          state module: MyApp.Form.CustomState
        end
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `field` - `MishkaGervaz.Form.Web.State.FieldBuilder.Default`
  - `group` - `MishkaGervaz.Form.Web.State.GroupBuilder.Default`
  - `step` - `MishkaGervaz.Form.Web.State.StepBuilder.Default`
  - `presentation` - `MishkaGervaz.Form.Web.State.Presentation.Default`
  - `access` - `MishkaGervaz.Form.Web.State.Access.Default`
  """

  @state_schema [
    module: [
      type: :atom,
      doc: """
      Override the entire state module. When set, all other options are ignored.
      The module must `use MishkaGervaz.Form.Web.State`.
      """
    ],
    field: [
      type: :atom,
      doc: """
      Field builder module. Must `use MishkaGervaz.Form.Web.State.FieldBuilder`.
      Builds field configs from DSL and resource configuration.
      """
    ],
    group: [
      type: :atom,
      doc: """
      Group builder module. Must `use MishkaGervaz.Form.Web.State.GroupBuilder`.
      Builds group layout from DSL configuration.
      """
    ],
    step: [
      type: :atom,
      doc: """
      Step builder module. Must `use MishkaGervaz.Form.Web.State.StepBuilder`.
      Builds wizard/tab steps from DSL configuration.
      """
    ],
    presentation: [
      type: :atom,
      doc: """
      Presentation module. Must `use MishkaGervaz.Form.Web.State.Presentation`.
      Resolves UI adapter, templates, and presentation options.
      """
    ],
    access: [
      type: :atom,
      doc: """
      Access module. Must `use MishkaGervaz.Form.Web.State.Access`.
      Handles access control for form actions.
      """
    ]
  ]

  @doc false
  def schema, do: @state_schema

  @doc """
  Returns the state section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :state,
      describe: "Override state management modules.",
      schema: @state_schema
    }
  end
end
