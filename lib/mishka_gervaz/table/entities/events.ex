defmodule MishkaGervaz.Table.Entities.Events do
  @moduledoc """
  Entity struct for events configuration.

  Allows overriding event handling modules at DSL level.

  ## Usage

  Override entire events module (positional argument):

      events MyApp.Table.CustomEvents

  Override specific sub-builders (block syntax):

      events do
        sanitization MyApp.Table.Events.SanitizationHandler
        record MyApp.Table.Events.RecordHandler
        selection MyApp.Table.Events.SelectionHandler
        bulk_action MyApp.Table.Events.BulkActionHandler
        hooks MyApp.Table.Events.HookRunner
        relation_filter MyApp.Table.Events.RelationFilterHandler
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `sanitization` - `MishkaGervaz.Table.Web.Events.SanitizationHandler.Default`
  - `record` - `MishkaGervaz.Table.Web.Events.RecordHandler.Default`
  - `selection` - `MishkaGervaz.Table.Web.Events.SelectionHandler.Default`
  - `bulk_action` - `MishkaGervaz.Table.Web.Events.BulkActionHandler.Default`
  - `hooks` - `MishkaGervaz.Table.Web.Events.HookRunner.Default`
  - `relation_filter` - `MishkaGervaz.Table.Web.Events.RelationFilterHandler.Default`
  """

  @type t :: %__MODULE__{
          module: module() | nil,
          sanitization: module() | nil,
          record: module() | nil,
          selection: module() | nil,
          bulk_action: module() | nil,
          hooks: module() | nil,
          relation_filter: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct module: nil,
            sanitization: nil,
            record: nil,
            selection: nil,
            bulk_action: nil,
            hooks: nil,
            relation_filter: nil,
            __spark_metadata__: nil

  @opt_schema [
    module: [
      type: :atom,
      doc: """
      Override the entire events module. When set, all other options are ignored.
      The module must `use MishkaGervaz.Table.Web.Events`.
      """
    ],
    sanitization: [
      type: :atom,
      doc: """
      Sanitization handler module. Must `use MishkaGervaz.Table.Web.Events.SanitizationHandler`.
      Handles input sanitization to prevent XSS.
      """
    ],
    record: [
      type: :atom,
      doc: """
      Record handler module. Must `use MishkaGervaz.Table.Web.Events.RecordHandler`.
      Handles record CRUD operations.
      """
    ],
    selection: [
      type: :atom,
      doc: """
      Selection handler module. Must `use MishkaGervaz.Table.Web.Events.SelectionHandler`.
      Manages row selection state.
      """
    ],
    bulk_action: [
      type: :atom,
      doc: """
      Bulk action handler module. Must `use MishkaGervaz.Table.Web.Events.BulkActionHandler`.
      Executes bulk actions on selected records.
      """
    ],
    hooks: [
      type: :atom,
      doc: """
      Hook runner module. Must `use MishkaGervaz.Table.Web.Events.HookRunner`.
      Executes hooks during event handling.
      """
    ],
    relation_filter: [
      type: :atom,
      doc: """
      Relation filter handler module. Must `use MishkaGervaz.Table.Web.Events.RelationFilterHandler`.
      Handles relation filter events (search, load_more, focus, close_dropdown, toggle).
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
