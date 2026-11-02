defmodule MishkaGervaz.Table.Dsl.RowActions do
  @moduledoc """
  Row actions section DSL definition for table configuration.

  Defines per-row action buttons and dropdowns.
  """

  alias MishkaGervaz.Table.Entities.RowAction
  alias MishkaGervaz.Table.Entities.RowActionDropdown
  alias MishkaGervaz.Table.Entities.DropdownSeparator

  defp row_action_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI configuration for the row action.",
      target: RowAction.Ui,
      schema: RowAction.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {RowAction.Ui, :transform, []}
    }
  end

  defp row_action_entity do
    %Spark.Dsl.Entity{
      name: :action,
      describe: "Define a per-row action.",
      target: RowAction,
      args: [:name],
      identifier: :name,
      schema: RowAction.opt_schema(),
      entities: [ui: [row_action_ui_entity()]],
      transform: {RowAction, :transform, []}
    }
  end

  defp separator_entity do
    %Spark.Dsl.Entity{
      name: :separator,
      describe: "Add a separator in the dropdown.",
      target: DropdownSeparator,
      schema: DropdownSeparator.opt_schema(),
      transform: {DropdownSeparator, :transform, []}
    }
  end

  defp dropdown_entity do
    %Spark.Dsl.Entity{
      name: :dropdown,
      describe: "Define a dropdown menu for row actions.",
      target: RowActionDropdown,
      args: [:name],
      identifier: :name,
      schema: RowActionDropdown.opt_schema(),
      entities: [
        items: [row_action_entity(), separator_entity()],
        ui: [row_action_ui_entity()]
      ],
      transform: {RowActionDropdown, :transform, []}
    }
  end

  @actions_layout_schema [
    position: [
      type: {:in, [:start, :end]},
      default: :end,
      doc: "Which side of row."
    ],
    sticky: [
      type: :boolean,
      default: true,
      doc: "Stick on horizontal scroll."
    ],
    inline: [
      type: {:list, :atom},
      doc: "Actions shown as buttons."
    ],
    dropdown: [
      type: {:list, :atom},
      default: [],
      doc: "Actions in dropdown menu."
    ],
    auto_collapse_after: [
      type: :integer,
      doc: "Auto-collapse after N actions."
    ],
    width: [
      type: :string,
      doc: """
      The Actions column's track in the plain table's grid, such as `"minmax(96px,max-content)"`.
      Without it the track is `max-content`, as wide as the widest Actions cell on the page. Give
      it the width of the most controls a row can show when rows show different ones, so a row
      whose buttons change never moves the other columns.
      """
    ]
  ]

  defp actions_layout_section do
    %Spark.Dsl.Section{
      name: :actions_layout,
      describe: "Layout configuration for row actions.",
      schema: @actions_layout_schema
    }
  end

  @doc """
  Returns the row_actions section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :row_actions,
      describe: "Per-row action buttons.",
      entities: [row_action_entity(), dropdown_entity()],
      sections: [actions_layout_section()]
    }
  end
end
