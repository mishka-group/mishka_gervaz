defmodule MishkaGervaz.Table.Dsl.Navigation do
  @moduledoc """
  DSL section for domain-level navigation configuration.

  Defines menu groups and navigation structure for admin UI.

  Used by `MishkaGervaz.Domain` extension.
  """

  alias MishkaGervaz.Table.Entities.MenuGroup

  defp menu_group_entity do
    %Spark.Dsl.Entity{
      name: :menu_group,
      describe: "A menu group in the admin navigation.",
      target: MenuGroup,
      args: [:name],
      schema: MenuGroup.opt_schema(),
      transform: {MenuGroup, :transform, []}
    }
  end

  @schema []

  def section do
    %Spark.Dsl.Section{
      name: :navigation,
      describe: "Navigation and menu configuration for admin UI.",
      schema: @schema,
      entities: [
        menu_group_entity()
      ]
    }
  end
end
