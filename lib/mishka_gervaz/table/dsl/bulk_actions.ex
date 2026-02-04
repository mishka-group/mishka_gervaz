defmodule MishkaGervaz.Table.Dsl.BulkActions do
  @moduledoc """
  Bulk actions section DSL definition for table configuration.

  Defines actions that operate on multiple selected rows.
  """

  alias MishkaGervaz.Table.Entities.BulkAction

  defp bulk_action_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI configuration for the bulk action.",
      target: BulkAction.Ui,
      schema: BulkAction.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {BulkAction.Ui, :transform, []}
    }
  end

  defp bulk_action_entity do
    %Spark.Dsl.Entity{
      name: :action,
      describe: "Define a bulk action.",
      target: BulkAction,
      args: [:name],
      identifier: :name,
      schema: BulkAction.opt_schema(),
      entities: [ui: [bulk_action_ui_entity()]],
      transform: {BulkAction, :transform, []}
    }
  end

  @section_schema [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable bulk actions."
    ]
  ]

  @doc false
  def schema, do: @section_schema

  @doc """
  Returns the bulk_actions section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :bulk_actions,
      describe: "Actions on multiple selected rows.",
      schema: @section_schema,
      entities: [bulk_action_entity()]
    }
  end
end
