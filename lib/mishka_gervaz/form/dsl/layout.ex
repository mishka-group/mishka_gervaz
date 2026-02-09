defmodule MishkaGervaz.Form.Dsl.Layout do
  @moduledoc """
  Layout section DSL definition for form configuration.

  Defines form layout structure including grid columns, wizard/tabs mode,
  step definitions, navigation, and responsiveness.
  """

  alias MishkaGervaz.Form.Entities.Step

  @layout_schema [
    columns: [
      type: {:in, [1, 2, 3, 4]},
      default: 1,
      doc: "Number of grid columns (1-4)."
    ],
    mode: [
      type: {:in, [:standard, :wizard, :tabs]},
      default: :standard,
      doc: "Form layout mode."
    ],
    navigation: [
      type: {:in, [:sequential, :free]},
      default: :sequential,
      doc: "Step navigation strategy. `:sequential` enforces order, `:free` allows jumping."
    ],
    persistence: [
      type: {:in, [:none, :ets, :client_token]},
      default: :none,
      doc: "Where to persist step data between navigations."
    ],
    responsive: [
      type: :boolean,
      default: true,
      doc: "Enable responsive layout adjustments."
    ]
  ]

  @doc false
  def schema, do: @layout_schema

  defp step_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for the step.",
      target: Step.Ui,
      schema: Step.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Step.Ui, :transform, []}
    }
  end

  defp step_entity do
    %Spark.Dsl.Entity{
      name: :step,
      describe: "Define a wizard/tab step.",
      target: Step,
      args: [:name],
      identifier: :name,
      schema: Step.opt_schema(),
      entities: [ui: [step_ui_entity()]],
      transform: {Step, :transform, []}
    }
  end

  @doc """
  Returns the layout section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :layout,
      describe: "Form layout configuration.",
      schema: @layout_schema,
      entities: [step_entity()]
    }
  end
end
