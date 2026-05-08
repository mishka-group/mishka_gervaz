defmodule MishkaGervaz.Form.Dsl.Layout do
  @moduledoc """
  Layout section — grid, mode, step navigation, and the form chrome
  (`header` / `footer` / `notice`).

  Three modes drive the rendering shape:

    * `:standard` — single page, all groups visible.
    * `:wizard` — step-by-step, only the current step renders.
    * `:tabs` — every step rendered as a tab/accordion.

  `:wizard` and `:tabs` require one or more `step` entities. Step flow is
  controlled by `navigation` (`:sequential` enforces order, `:free` lets
  users jump) and step state is held according to `persistence`
  (`:none`, `:ets`, or `:client_token`).

  ## Example — standard layout

      layout do
        columns 2
        mode :standard
        responsive true
      end

  ## Example — wizard with steps

      layout do
        mode :wizard
        columns 2
        navigation :sequential
        persistence :ets

        step :details do
          groups [:basic]

          ui do
            label "Details"
            icon "hero-information-circle"
          end
        end

        step :review do
          groups [:flags]
          summary true

          ui do
            label "Review"
          end
        end
      end

  ## Chrome entities

  `header`, `footer`, and `notice` render around (or between) the form
  fields. Each supports `visible` and `restricted` predicates with the
  same access conventions used by `field` / `group`. `notice` accepts a
  `position` (e.g. `:before_fields`, `:before_submit`,
  `{:after_group, :basic}`), a `type` (`:info` / `:warning` / `:error` /
  `:success` / `:neutral`), and an optional `bind_to` for binding to
  validation state.

      layout do
        header do
          title "Account Permissions"
          description "Configure what this account can access."
        end

        notice :read_only_banner do
          position :before_fields
          type :warning
          title "Read-Only Access"
          visible fn state -> state.master_user? == false end
        end
      end

  See `MishkaGervaz.Form.Entities.{Step, Header, Footer, Notice}` for
  the full option list per entity.
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
