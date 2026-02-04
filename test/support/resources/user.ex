defmodule MishkaGervaz.Test.Resources.User do
  @moduledoc """
  Test user resource for MishkaGervaz tests.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :users
        route "/admin/users"
      end

      columns do
        column :name do
          sortable true
          searchable true

          ui do
            label "Full Name"
          end
        end

        column :email do
          sortable true
          searchable true
        end

        column :role do
          sortable true

          ui do
            label "User Role"
            type :badge
          end
        end

        column :active do
          ui do
            type :boolean
          end
        end

        column :inserted_at do
          sortable true

          ui do
            type :datetime
          end
        end
      end

      filters do
        filter :search, :text do
          fields [:name, :email]

          ui do
            label "Search"
            placeholder "Search users..."
          end
        end

        filter :role, :select do
          options [
            [value: "admin", label: "Admin"],
            [value: "user", label: "User"],
            [value: "guest", label: "Guest"]
          ]

          ui do
            label "Role"
          end
        end

        filter :active, :boolean do
          ui do
            label "Active Only"
          end
        end
      end

      row_actions do
        action :show do
          type :link
          path fn record -> "/admin/users/#{record.id}" end

          ui do
            label "View"
            icon "hero-eye"
          end
        end

        action :edit do
          type :link
          path fn record -> "/admin/users/#{record.id}/edit" end

          ui do
            label "Edit"
            icon "hero-pencil"
          end
        end

        action :delete do
          type :destroy
          confirm "Are you sure you want to delete this user?"

          ui do
            label "Delete"
            icon "hero-trash"
          end
        end
      end

      bulk_actions do
        action :delete do
          confirm "Delete selected users?"
        end
      end

      pagination page_size: 20, type: :numbered
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      prepare build(sort: [inserted_at: :desc])
    end

    read :tenant_read do
      prepare build(sort: [inserted_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      constraints one_of: [:admin, :user, :guest]
      default :user
      public? true
    end

    attribute :active, :boolean do
      default true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :posts, MishkaGervaz.Test.Resources.Post
    has_many :comments, MishkaGervaz.Test.Resources.Comment
  end
end
