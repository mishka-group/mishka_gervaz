defmodule MishkaGervaz.Table.Dsl.Events do
  @moduledoc """
  Events entity DSL definition for table configuration.

  Allows overriding event handling modules at DSL level.
  Supports both positional argument and block syntax:

  ## Usage

  Override entire events module (positional argument):

      mishka_gervaz do
        table do
          events MyApp.Table.CustomEvents
        end
      end

  Override specific sub-builders (block syntax):

      mishka_gervaz do
        table do
          events do
            sanitization MyApp.Table.Events.SanitizationHandler
            record MyApp.Table.Events.RecordHandler
            selection MyApp.Table.Events.SelectionHandler
            bulk_action MyApp.Table.Events.BulkActionHandler
            hooks MyApp.Table.Events.HookRunner
            relation_filter MyApp.Table.Events.RelationFilterHandler
          end
        end
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

  alias MishkaGervaz.Table.Entities.Events

  @doc """
  Returns the events entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :events,
      describe: "Override event handling modules.",
      target: Events,
      args: [:module],
      schema: Events.opt_schema(),
      singleton_entity_keys: [:events],
      transform: {Events, :transform, []}
    }
  end
end
