defmodule MishkaGervaz.Table.Dsl.Views do
  @moduledoc """
  The `view` entity: a named table over the same resource, with its own columns and base filter.

      table do
        identity do
          name :orders
          route "/admin/orders"
        end

        columns do
          column :number
          column :customer
          column :total
        end

        view :refunds do
          filter expr(not is_nil(refunded_at))

          columns do
            default_sort refunded_at: :desc

            column :number
            column :refund_reason
            column :amount_refunded
          end
        end
      end

  A mount draws the view with `view={:refunds}`; without it the table draws its own columns.
  Everything but the columns and the base filter is the table's: filters, row and bulk actions,
  pagination, realtime and presentation.
  """

  alias MishkaGervaz.Table.Dsl.Columns
  alias MishkaGervaz.Table.Entities.View

  @schema [
    name: [
      type: :atom,
      required: true,
      doc: "The view's name, the value of the mount's `view` assign."
    ],
    filter: [
      type: :any,
      doc:
        "A base filter every read of the view applies, an Ash expression such as `expr(status == :refunded)` or a keyword list. The reader cannot clear it."
    ]
  ]

  @doc false
  def schema, do: @schema

  defp columns_entity do
    %Spark.Dsl.Entity{
      name: :columns,
      describe: "The view's columns, with the options of the table's `columns` section.",
      target: View.Columns,
      schema: Columns.schema(),
      entities: [columns: [Columns.column_entity()]]
    }
  end

  @doc """
  Returns the view entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :view,
      describe: "A named table over the same resource, with its own columns and base filter.",
      target: View,
      args: [:name],
      identifier: :name,
      imports: [Ash.Expr],
      schema: @schema,
      entities: [column_set: [columns_entity()]],
      singleton_entity_keys: [:column_set]
    }
  end
end
