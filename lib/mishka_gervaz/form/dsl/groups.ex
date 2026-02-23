defmodule MishkaGervaz.Form.Dsl.Groups do
  @moduledoc """
  Groups section DSL definition for form configuration.

  Defines field grouping for form layout organization.
  """

  alias MishkaGervaz.Form.Entities.Group

  defp group_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for the group.",
      target: Group.Ui,
      schema: Group.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Group.Ui, :transform, []}
    }
  end

  defp group_entity do
    %Spark.Dsl.Entity{
      name: :group,
      describe: "Define a field group.",
      target: Group,
      args: [:name],
      identifier: :name,
      schema: Group.opt_schema(),
      entities: [ui: [group_ui_entity()]],
      transform: {Group, :transform, []}
    }
  end

  @doc """
  Returns the groups section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :groups,
      describe: "Define field groups.",
      entities: [group_entity()]
    }
  end
end
