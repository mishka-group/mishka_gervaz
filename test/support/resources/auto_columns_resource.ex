defmodule MishkaGervaz.Test.Resources.AutoColumnsResource do
  @moduledoc """
  Test resource for auto_columns feature testing.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :auto_test
        route "/admin/auto-test"
      end

      columns do
        auto_columns do
          except [:internal_field, :updated_at]

          defaults do
            sortable true
            searchable false
          end

          override :title do
            searchable true

            ui do
              label "Custom Title Label"
            end
          end

          override :count do
            sortable false
          end

          override :active do
            visible true
          end

          override :inserted_at do
            format(fn value -> Calendar.strftime(value, "%d/%m/%Y") end)
          end
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :count, :integer do
      default 0
      public? true
    end

    attribute :active, :boolean do
      default true
      public? true
    end

    attribute :internal_field, :string do
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
