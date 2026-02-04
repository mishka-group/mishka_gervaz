defmodule MishkaGervaz.Test.Resources.Comment do
  @moduledoc """
  Test comment resource for relationship filter testing.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :comments
        route "/admin/comments"
      end

      source do
        preload do
          always [:user, :post]
        end
      end

      columns do
        column :body do
          searchable true

          ui do
            label "Comment"
          end
        end

        column :user do
          source [:user, :name]

          ui do
            label "Author"
          end
        end

        column :post do
          source [:post, :title]

          ui do
            label "Post"
          end
        end

        column :approved do
          ui do
            label "Approved"
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
        filter :post_id, :relation do
          resource MishkaGervaz.Test.Resources.Post
          display_field :title

          ui do
            label "Post"
          end
        end

        filter :user_id, :relation do
          resource MishkaGervaz.Test.Resources.User
          display_field :name
          depends_on :post_id

          ui do
            label "Author"
            disabled_prompt "Select a post first"
          end
        end

        filter :approved, :boolean do
          ui do
            label "Approved Only"
          end
        end
      end

      row_actions do
        action :approve do
          type :event
          event "approve_comment"
          visible fn record, _state -> !record.approved end

          ui do
            label "Approve"
            icon "hero-check"
          end
        end

        action :delete do
          type :destroy
          confirm "Delete this comment?"
        end
      end

      pagination page_size: 50, type: :numbered
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :approved, :boolean do
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :post, MishkaGervaz.Test.Resources.Post do
      allow_nil? false
      public? true
    end

    belongs_to :user, MishkaGervaz.Test.Resources.User do
      allow_nil? false
      public? true
    end
  end
end
