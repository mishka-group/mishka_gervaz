defmodule MishkaGervaz.Test.Resources.Post do
  @moduledoc """
  Test post resource for MishkaGervaz tests.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  import Phoenix.Component, only: [sigil_H: 2]

  mishka_gervaz do
    table do
      identity do
        name :posts
        route "/admin/posts"
        stream_name :posts_stream
      end

      source do
        actor_key :current_user
        master_check fn user -> user && user.role == :admin end

        actions do
          read {:master_read, :tenant_read}
          destroy {:destroy, :destroy}
        end

        preload do
          always [:user]
        end
      end

      realtime enabled: false

      columns do
        column_order [:title, :status, :user, :view_count, :inserted_at]
        default_sort {:inserted_at, :desc}

        column :title do
          sortable true
          searchable true

          ui do
            label "Title"
            class "font-semibold"
          end
        end

        column :status do
          sortable true

          ui do
            label "Status"
            type :badge
          end
        end

        column :user do
          source [:user, :name]
          sortable false

          ui do
            label "Author"
          end
        end

        column :view_count do
          sortable true

          ui do
            label "Views"
            type :number
          end
        end

        column :inserted_at do
          sortable true
          format fn value -> Calendar.strftime(value, "%Y/%m/%d %H:%M") end

          ui do
            label "Created"
            type :datetime
          end
        end

        column :view_count_formatted do
          source :view_count
          format fn _state, _record, value -> "#{value} views" end
        end
      end

      filters do
        filter :search, :text do
          fields [:title, :content]

          ui do
            placeholder "Search posts..."
          end
        end

        filter :status, :select do
          options [
            [value: "draft", label: "Draft"],
            [value: "published", label: "Published"],
            [value: "archived", label: "Archived"]
          ]

          default "published"
        end

        filter :user_id, :relation do
          resource MishkaGervaz.Test.Resources.User
          display_field :name

          preload do
            always [:posts]
          end

          ui do
            label "Author"
          end
        end
      end

      row_actions do
        action :show do
          type :link
          path fn record -> "/admin/posts/#{record.id}" end
        end

        action :edit do
          type :link
          path fn record -> "/admin/posts/#{record.id}/edit" end
        end

        action :publish do
          type :event
          event "publish_post"
          visible fn record, _state -> record.status == :draft end

          ui do
            label "Publish"
            icon "hero-rocket-launch"
          end
        end

        action :delete do
          type :destroy
          confirm "Are you sure you want to delete this post?"
        end

        action :custom_view do
          type :link
          path fn record -> "/admin/posts/#{record.id}" end

          render fn record ->
            assigns = %{record: record}

            ~H"""
            <a href={"/admin/posts/#{@record.id}"} class="custom-view-link">
              Custom View
            </a>
            """
          end
        end

        action :custom_action do
          type :event
          event "custom_event"

          render fn record, action ->
            assigns = %{record: record, action: action}

            ~H"""
            <button phx-click={@action.event} phx-value-id={@record.id} class="custom-action-btn">
              Custom Action for {@record.title}
            </button>
            """
          end
        end
      end

      row do
        selectable true

        override do
          condition fn record -> record.status == :draft end

          render fn assigns, record, _columns ->
            assigns = Map.put(assigns, :record, record)

            ~H"""
            <td colspan="100" class="bg-yellow-50 border-l-4 border-yellow-400 p-4">
              <div class="flex items-center gap-2">
                <span class="text-yellow-600 font-semibold">📝 DRAFT:</span>
                <span class="text-gray-700">{@record.title}</span>
                <span class="text-sm text-gray-500">(This is a custom row override for drafts)</span>
              </div>
            </td>
            """
          end
        end
      end

      bulk_actions do
        action :delete do
          confirm "Delete selected posts?"
        end
      end

      pagination page_size: 25, type: :infinite

      empty_state message: "No posts found", icon: "hero-document-text"

      error_state message: "Failed to load posts"

      presentation do
        ui_adapter MishkaGervaz.Table.UIAdapters.Tailwind
        template MishkaGervaz.Table.Templates.Table
      end

      refresh do
        enabled false
      end

      url_sync do
        enabled true
        mode :bidirectional
        params [:page, :sort, :search, :filters]
        preserve_params [:return_to]
      end

      hooks do
        on_load fn socket, _data -> socket end
        before_delete fn _record, socket -> {:ok, socket} end
        after_delete fn _record, socket -> socket end
        on_filter fn _filters, socket -> socket end
        on_select fn _ids, socket -> socket end
        on_sort fn _sort, socket -> socket end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      prepare build(sort: [inserted_at: :desc])
    end

    read :tenant_read do
      filter expr(status == :published)
      prepare build(sort: [inserted_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :content, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
      public? true
    end

    attribute :view_count, :integer do
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, MishkaGervaz.Test.Resources.User do
      allow_nil? false
      public? true
    end

    has_many :comments, MishkaGervaz.Test.Resources.Comment
  end
end
