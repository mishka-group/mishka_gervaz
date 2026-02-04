defmodule MishkaGervaz.Table.Dsl.State do
  @moduledoc """
  State section DSL definition for table configuration.

  Allows overriding state management modules at DSL level.

  ## Usage

  Override specific sub-builders:

      mishka_gervaz do
        table do
          state do
            column MyApp.Table.ColumnBuilder
            filter MyApp.Table.FilterBuilder
            action MyApp.Table.ActionBuilder
            presentation MyApp.Table.Presentation
            url_sync MyApp.Table.UrlSync
            access MyApp.Table.Access
          end
        end
      end

  Or override the entire state module:

      mishka_gervaz do
        table do
          state module: MyApp.Table.CustomState
        end
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `column` - `MishkaGervaz.Table.Web.State.ColumnBuilder.Default`
  - `filter` - `MishkaGervaz.Table.Web.State.FilterBuilder.Default`
  - `action` - `MishkaGervaz.Table.Web.State.ActionBuilder.Default`
  - `presentation` - `MishkaGervaz.Table.Web.State.Presentation.Default`
  - `url_sync` - `MishkaGervaz.Table.Web.State.UrlSync.Default`
  - `access` - `MishkaGervaz.Table.Web.State.Access.Default`
  """

  @state_schema [
    module: [
      type: :atom,
      doc: """
      Override the entire state module. When set, all other options are ignored.
      The module must `use MishkaGervaz.Table.Web.State`.
      """
    ],
    column: [
      type: :atom,
      doc: """
      Column builder module. Must `use MishkaGervaz.Table.Web.State.ColumnBuilder`.
      Builds columns from DSL and resource configuration.
      """
    ],
    filter: [
      type: :atom,
      doc: """
      Filter builder module. Must `use MishkaGervaz.Table.Web.State.FilterBuilder`.
      Builds filters from DSL and resource configuration.
      """
    ],
    action: [
      type: :atom,
      doc: """
      Action builder module. Must `use MishkaGervaz.Table.Web.State.ActionBuilder`.
      Builds row actions and bulk actions from configuration.
      """
    ],
    presentation: [
      type: :atom,
      doc: """
      Presentation module. Must `use MishkaGervaz.Table.Web.State.Presentation`.
      Resolves UI adapter, templates, and presentation options.
      """
    ],
    url_sync: [
      type: :atom,
      doc: """
      URL sync module. Must `use MishkaGervaz.Table.Web.State.UrlSync`.
      Handles URL state synchronization.
      """
    ],
    access: [
      type: :atom,
      doc: """
      Access module. Must `use MishkaGervaz.Table.Web.State.Access`.
      Handles access control for records and actions.
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
