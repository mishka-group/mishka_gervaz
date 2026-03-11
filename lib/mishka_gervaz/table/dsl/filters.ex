defmodule MishkaGervaz.Table.Dsl.Filters do
  @moduledoc """
  Filters section DSL definition for table configuration.

  Defines filter inputs with support for various filter types.
  """

  alias MishkaGervaz.Table.Entities.Filter

  defp filter_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI configuration for the filter.",
      target: Filter.Ui,
      schema: Filter.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Filter.Ui, :transform, []}
    }
  end

  defp filter_preload_entity do
    %Spark.Dsl.Entity{
      name: :preload,
      describe: """
      Preload configuration for relation filters.

      Defines which relationships to load for display_field rendering.

      Example:
          preload do
            always [:site]
            tenant [:category]
            master master_category: :category
          end
      """,
      target: Filter.Preload,
      schema: Filter.Preload.opt_schema(),
      singleton_entity_keys: [:preload],
      transform: {Filter.Preload, :transform, []}
    }
  end

  defp filter_entity do
    %Spark.Dsl.Entity{
      name: :filter,
      describe: "Define a filter input.",
      target: Filter,
      args: [:name, :type],
      identifier: :name,
      schema: Filter.opt_schema(),
      entities: [ui: [filter_ui_entity()], preload: [filter_preload_entity()]],
      transform: {Filter, :transform, []}
    }
  end

  @doc """
  Returns the filters section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :filters,
      describe: "Filter input configuration.",
      entities: [filter_entity()]
    }
  end
end
