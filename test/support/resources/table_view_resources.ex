defmodule MishkaGervaz.Test.Resources.ViewedOrder do
  @moduledoc """
  An order table with a named view: the table shows `:number`, `:customer` and `:total` by number,
  two to a page, and the
  `:refunds` view shows `:number`, `:refund_reason` and `:amount_refunded` of refunded orders only,
  newest refund first.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  mishka_gervaz do
    table do
      identity do
        name :viewed_orders
        route "/admin/orders"
      end

      columns do
        default_sort number: :asc

        column :number, sortable: true
        column :customer
        column :total
      end

      pagination type: :numbered, page_size: 2

      view :refunds do
        filter expr(refunded == true)

        columns do
          default_sort amount_refunded: :desc

          column :number
          column :refund_reason

          column :amount_refunded do
            sortable true
            label "Refunded"
          end
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :number, :integer, public?: true
    attribute :customer, :string, public?: true
    attribute :total, :integer, public?: true
    attribute :refunded, :boolean, public?: true, default: false
    attribute :refund_reason, :string, public?: true
    attribute :amount_refunded, :integer, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_get

    read :master_read do
      pagination offset?: true, keyset?: true, countable: true, required?: false
    end

    read :tenant_read do
      pagination offset?: true, keyset?: true, countable: true, required?: false
    end

    destroy :master_destroy
  end
end
