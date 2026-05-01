defmodule MishkaGervaz.Form.Dsl.Layout do
  @moduledoc """
  Layout section DSL definition for form configuration.

  Defines form layout structure including grid columns, wizard/tabs mode,
  step definitions, navigation, responsiveness, and the form chrome —
  header, footer, and notices (alerts/banners).

  Each chrome entity (`header`, `footer`, `notice`) supports `visible` and
  `restricted` for the same access conventions used by `field`/`group`.
  """

  alias MishkaGervaz.Form.Entities.{Step, Header, Footer, Notice}

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

  defp header_entity do
    %Spark.Dsl.Entity{
      name: :header,
      describe: "Static form header (title + description) rendered above the fields.",
      target: Header,
      schema: Header.opt_schema(),
      singleton_entity_keys: [:header],
      transform: {Header, :transform, []}
    }
  end

  defp footer_entity do
    %Spark.Dsl.Entity{
      name: :footer,
      describe: "Static form footer rendered below the submit row.",
      target: Footer,
      schema: Footer.opt_schema(),
      singleton_entity_keys: [:footer],
      transform: {Footer, :transform, []}
    }
  end

  defp notice_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for the notice.",
      target: Notice.Ui,
      schema: Notice.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Notice.Ui, :transform, []}
    }
  end

  defp notice_entity do
    %Spark.Dsl.Entity{
      name: :notice,
      describe: "Static alert/banner with positioning and validation binding.",
      target: Notice,
      args: [:name],
      identifier: :name,
      schema: Notice.opt_schema(),
      entities: [ui: [notice_ui_entity()]],
      transform: {Notice, :transform, []}
    }
  end

  @doc """
  Returns the layout section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :layout,
      describe: "Form layout configuration including chrome (header/footer/notices).",
      schema: @layout_schema,
      entities: [step_entity(), header_entity(), footer_entity(), notice_entity()]
    }
  end
end
