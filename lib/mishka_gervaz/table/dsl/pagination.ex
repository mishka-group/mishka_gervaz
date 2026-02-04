defmodule MishkaGervaz.Table.Dsl.Pagination do
  @moduledoc """
  Pagination entity DSL definition for table configuration.

  Supports both inline and block syntax:

      # Inline
      pagination type: :infinite, page_size: 25

      # Block with UI customization
      pagination do
        type :infinite
        page_size 25

        ui do
          load_more_label "Show More"
          show_total true
        end
      end
  """

  alias MishkaGervaz.Table.Entities.Pagination

  defp ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for pagination.",
      target: Pagination.Ui,
      schema: Pagination.Ui.opt_schema(),
      transform: {Pagination.Ui, :transform, []}
    }
  end

  @doc """
  Returns the pagination entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :pagination,
      describe: "Pagination configuration.",
      target: Pagination,
      schema: Pagination.opt_schema(),
      entities: [ui: [ui_entity()]],
      transform: {Pagination, :transform, []}
    }
  end
end
