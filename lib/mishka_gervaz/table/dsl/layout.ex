defmodule MishkaGervaz.Table.Dsl.Layout do
  @moduledoc """
  Layout section DSL definition for table configuration.

  Holds the table chrome — `header`, `footer`, and `notice` entities —
  mirroring the form layout section so authors learn one pattern.

  Each chrome entity supports `visible` and `restricted` for the same
  access conventions used by `column`/`filter`/`row_action`.

  ## Example

      mishka_gervaz do
        table do
          identity do
            name :pages
          end

          layout do
            header do
              title "Pages"
              description "All published and draft pages."
              icon "hero-document-text"
            end

            footer do
              content "Sorted by priority."
              class "mt-2 text-xs text-gray-400"
            end

            notice :archived_warning do
              position :before_table
              type :warning
              icon "hero-archive-box"
              title "Viewing archived records"
              bind_to :archived_view
            end
          end

          columns do
            column :name
          end
        end
      end
  """

  alias MishkaGervaz.Table.Entities.{Header, Footer, Notice}

  defp header_entity do
    %Spark.Dsl.Entity{
      name: :header,
      describe: "Static table header (title + description) rendered above the toolbar.",
      target: Header,
      schema: Header.opt_schema(),
      singleton_entity_keys: [:header],
      transform: {Header, :transform, []}
    }
  end

  defp footer_entity do
    %Spark.Dsl.Entity{
      name: :footer,
      describe: "Static table footer rendered below pagination.",
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
      describe: "Static alert/banner with positioning and bind_to wiring.",
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
      describe: "Table layout configuration including chrome (header/footer/notices).",
      entities: [header_entity(), footer_entity(), notice_entity()]
    }
  end
end
