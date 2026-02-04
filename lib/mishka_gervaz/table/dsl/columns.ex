defmodule MishkaGervaz.Table.Dsl.Columns do
  @moduledoc """
  Columns section DSL definition for table configuration.

  Defines table columns with support for manual columns and auto-discovery.
  """

  alias MishkaGervaz.Table.Entities.Column
  alias MishkaGervaz.Table.Entities.AutoColumns

  defp column_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for the column.",
      target: Column.Ui,
      schema: Column.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Column.Ui, :transform, []}
    }
  end

  defp column_entity do
    %Spark.Dsl.Entity{
      name: :column,
      describe: "Define a table column.",
      target: Column,
      args: [:name],
      identifier: :name,
      schema: Column.opt_schema(),
      entities: [ui: [column_ui_entity()]],
      transform: {Column, :transform, []}
    }
  end

  defp auto_columns_defaults_entity do
    %Spark.Dsl.Entity{
      name: :defaults,
      describe: "Default options for auto-discovered columns.",
      target: AutoColumns.Defaults,
      schema: AutoColumns.Defaults.opt_schema(),
      singleton_entity_keys: [:defaults],
      transform: {AutoColumns.Defaults, :transform, []}
    }
  end

  defp auto_columns_ui_defaults_entity do
    %Spark.Dsl.Entity{
      name: :ui_defaults,
      describe: "Default UI options for auto-discovered columns.",
      target: AutoColumns.UiDefaults,
      schema: AutoColumns.UiDefaults.opt_schema(),
      singleton_entity_keys: [:ui_defaults],
      transform: {AutoColumns.UiDefaults, :transform, []}
    }
  end

  defp auto_columns_override_entity do
    %Spark.Dsl.Entity{
      name: :override,
      describe: "Override a specific auto-discovered column.",
      target: AutoColumns.Override,
      args: [:name],
      schema: AutoColumns.Override.opt_schema(),
      entities: [ui: [column_ui_entity()]],
      transform: {AutoColumns.Override, :transform, []}
    }
  end

  defp auto_columns_entity do
    %Spark.Dsl.Entity{
      name: :auto_columns,
      describe: "Auto-discover columns from Ash resource attributes.",
      target: AutoColumns,
      schema: AutoColumns.opt_schema(),
      entities: [
        defaults: [auto_columns_defaults_entity()],
        ui_defaults: [auto_columns_ui_defaults_entity()],
        overrides: [auto_columns_override_entity()]
      ],
      transform: {AutoColumns, :transform, []}
    }
  end

  @section_schema [
    column_order: [
      type: {:list, :atom},
      doc: "Column display order. Columns not in list appear at end."
    ],
    default_sort: [
      type: :any,
      doc: "Default sort. Atom, tuple, or list of tuples."
    ]
  ]

  @doc false
  def schema, do: @section_schema

  @doc """
  Returns the columns section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :columns,
      describe: "Define table columns.",
      schema: @section_schema,
      entities: [column_entity(), auto_columns_entity()]
    }
  end
end
