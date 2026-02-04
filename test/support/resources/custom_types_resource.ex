defmodule MishkaGervaz.Test.Resources.CustomTypesResource do
  @moduledoc """
  Test resource for verifying custom type module support in DSL.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :custom_types_items
        route "/admin/custom-types"
      end

      columns do
        # Column with custom type module
        column :custom_field do
          ui do
            type MishkaGervaz.Test.CustomColumnType
          end
        end

        # Column with built-in type for comparison
        column :status do
          ui do
            type :badge
          end
        end

        # Column without explicit type (should auto-detect)
        column :name do
          sortable true
        end

        # Column with datetime type
        column :inserted_at do
          ui do
            type :datetime
          end
        end

        # Column with uuid type
        column :id do
          ui do
            type :uuid
          end
        end
      end

      filters do
        # Filter with custom type module
        filter :custom_filter, MishkaGervaz.Test.CustomFilterType

        # Filter with built-in type
        filter :status, :select do
          options [
            [value: "active", label: "Active"],
            [value: "inactive", label: "Inactive"]
          ]
        end
      end

      row_actions do
        # Action with custom type module
        action :custom_action do
          type MishkaGervaz.Test.CustomActionType
        end

        # Action with built-in type
        action :show do
          type :link
          path fn record -> "/admin/custom-types/#{record.id}" end
        end
      end

      pagination page_size: 10, type: :infinite
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :custom_field, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
