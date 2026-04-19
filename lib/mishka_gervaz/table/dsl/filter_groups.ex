defmodule MishkaGervaz.Table.Dsl.FilterGroups do
  @moduledoc """
  Filter groups section DSL definition for table configuration.

  Organizes filters into collapsible groups, independent of filter definitions.

  ## Example

      filter_groups do
        group :primary do
          filters [:search]
          collapsible false
        end

        group :advanced do
          filters [:status, :issue_type, :site_id]
          collapsible true
          collapsed true
          columns 3

          ui do
            label "Advanced Search"
            icon "hero-funnel"
          end
        end
      end
  """

  alias MishkaGervaz.Table.Entities.FilterGroup

  defp filter_group_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI configuration for the filter group.",
      target: FilterGroup.Ui,
      schema: FilterGroup.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {FilterGroup.Ui, :transform, []}
    }
  end

  defp filter_group_entity do
    %Spark.Dsl.Entity{
      name: :group,
      describe: """
      Define a filter group for organizing filters into collapsible sections.

      Example:
          group :advanced do
            filters [:status, :issue_type, :site_id]
            collapsible true
            collapsed true
            columns 3

            ui do
              label "Advanced Search"
              icon "hero-funnel"
            end
          end
      """,
      target: FilterGroup,
      args: [:name],
      identifier: :name,
      schema: FilterGroup.opt_schema(),
      entities: [ui: [filter_group_ui_entity()]],
      transform: {FilterGroup, :transform, []}
    }
  end

  @doc """
  Returns the filter_groups section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :filter_groups,
      describe: "Organize filters into collapsible groups.",
      entities: [filter_group_entity()]
    }
  end
end
