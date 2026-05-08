defmodule MishkaGervaz.Form.Dsl.Groups do
  @moduledoc """
  Groups section — bundles fields into named groups for layout and
  access control.

  A group references field names; the layout (and any wizard/tabs steps)
  arranges the fields inside each group. Groups also carry the standard
  `visible` / `restricted` predicates and an optional `ui` sub-entity
  for label, icon, description, and CSS classes. Groups are reusable
  units — wizard `step do groups [:basic, :meta] end` maps a step to a
  set of groups by name.

  ## Example

      groups do
        group :general do
          fields [:title, :content, :status, :language]
          position :first

          ui do
            label "General"
            icon "hero-pencil"
            description "Core fields"
            class "border p-4"
          end
        end

        group :settings do
          fields [:priority, :featured, :metadata, :user_id]
          collapsible true
          collapsed true

          ui do
            label "Settings"
          end
        end
      end

  See `MishkaGervaz.Form.Entities.Group` for the full option list.
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
