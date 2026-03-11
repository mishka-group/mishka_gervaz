defmodule MishkaGervaz.Test.Resources.ComplexTestResource do
  @moduledoc """
  Complex resource with ALL DSL keys for comprehensive testing.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.ComplexTestDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :complex_posts
        route "/admin/complex-posts"
        stream_name :complex_posts_stream
      end

      source do
        actor_key :current_user
        master_check fn user -> user && user.role == :admin end

        actions do
          read {:master_read, :tenant_read}
          get {:master_get, :read}
          destroy {:master_destroy, :destroy}
        end

        preload do
          always [:author]
        end
      end

      columns do
        column_order [:title, :status, :author, :view_count, :is_featured, :inserted_at]
        default_sort {:inserted_at, :desc}

        column :title do
          source :title
          sortable true
          searchable true
          filterable false
          visible true
          position :first
          export true
          export_as :post_title
          default "Untitled"
          separator " - "
          label "Post Title"

          ui do
            label "Title"
            type :text
            width "250px"
            min_width "150px"
            max_width "400px"
            align :left
            class "font-semibold"
            header_class "text-primary"
            extra %{truncate: 50}
          end
        end

        column :status do
          sortable true
          default :draft

          ui do
            type :badge

            extra %{
              colors: %{
                draft: "bg-gray-100 text-gray-800",
                published: "bg-green-100 text-green-800",
                archived: "bg-red-100 text-red-800"
              }
            }
          end
        end

        column :author do
          source {:author, :name}
          sortable false

          ui do
            type :text
            label "Author Name"
          end
        end

        column :view_count do
          sortable true

          ui do
            type :number
            align :right
            extra %{prefix: "", suffix: " views"}
          end
        end

        column :is_featured do
          ui do
            type :boolean
            align :center

            extra %{
              true_icon: "hero-star-solid",
              false_icon: "hero-star",
              true_class: "text-yellow-500",
              false_class: "text-gray-300"
            }
          end
        end

        column :inserted_at do
          sortable true

          ui do
            type :datetime
            extra %{format: "%Y-%m-%d %H:%M", relative: false}
          end
        end
      end

      filter_groups do
        group :primary do
          filters([:search])
          collapsible false
          position :first

          ui do
            label "Search"
          end
        end

        group :advanced do
          filters([:status, :is_featured, :author_id])
          collapsible true
          collapsed true

          ui do
            label "Advanced Filters"
            icon "hero-funnel"
            columns 3
          end
        end
      end

      filters do
        filter :search, :text do
          fields [:title, :content]
          visible true
          min_chars 3

          ui do
            label "Search"
            placeholder "Search posts..."
            icon "hero-magnifying-glass"
            debounce 400
            extra %{autofocus: true}
          end
        end

        filter :status, :select do
          source :status

          options [
            {"Draft", :draft},
            {"Published", :published},
            {"Archived", :archived}
          ]

          include_nil "All Statuses"

          ui do
            label "Status"
            prompt "All"
            icon "hero-funnel"
          end
        end

        filter :is_featured, :boolean do
          source :is_featured

          ui do
            label "Featured Only"
          end
        end

        filter :view_count, :number do
          source :view_count
          min 0
          max 1_000_000

          ui do
            label "Min Views"
            placeholder "Minimum views..."
          end
        end

        filter :published_at, :date do
          source :published_at

          ui do
            label "Published Date"
          end
        end

        filter :date_range, :date_range do
          source :inserted_at

          ui do
            label "Created Between"
          end
        end

        filter :author_id, :relation do
          source :author_id
          depends_on nil
          display_field :name
          search_field :name
          include_nil "No Author"

          ui do
            label "Author"
            prompt "Select Author"
            disabled_prompt "Select status first"
          end
        end
      end

      row_actions do
        actions_layout do
          position :end
          sticky true
          inline [:show, :edit]
          dropdown [:more_actions]
          auto_collapse_after 3
        end

        action :show do
          type :link
          path "/admin/complex-posts/{id}"
          visible true
          restricted false

          ui do
            label "View"
            icon "hero-eye"
            class "text-blue-600 hover:text-blue-800"
            extra %{tooltip: "View details"}
          end
        end

        action :edit do
          type :link
          path fn record -> "/admin/complex-posts/#{record.id}/edit" end
          visible :active
          restricted true

          ui do
            label "Edit"
            icon "hero-pencil"
            class "text-indigo-600 hover:text-indigo-800"
          end
        end

        action :delete do
          type :destroy
          confirm "Are you sure you want to delete this post?"
          visible :active
          restricted true

          ui do
            label "Delete"
            icon "hero-trash"
            class "text-red-600 hover:text-red-800"
          end
        end

        action :archive_action do
          type :event
          event :archive
          payload fn record -> %{id: record.id, title: record.title} end
          confirm fn record -> "Archive '#{record.title}'?" end
          visible :active
          restricted true

          ui do
            label "Archive"
            icon "hero-archive-box"
          end
        end

        action :restore do
          type :event
          event :restore
          visible :archived
          restricted true

          ui do
            label "Restore"
            icon "hero-arrow-uturn-left"
          end
        end

        action :publish_now do
          type :update
          action :publish
          visible :active
          restricted true

          ui do
            label "Publish"
            icon "hero-rocket-launch"
          end
        end

        action :feature do
          type :update
          action {:master_feature, :feature}
          confirm "Feature this post?"
          visible :active
          restricted true

          ui do
            label "Feature"
            icon "hero-star"
          end
        end

        action :edit_form do
          type :edit
          visible :active

          ui do
            label "Edit Form"
            icon "hero-pencil-square"
          end
        end

        action :edit_modal do
          type :edit
          visible :active
          js fn _record -> Phoenix.LiveView.JS.exec("data-show-modal", to: "#edit-modal") end

          ui do
            label "Edit Modal"
            icon "hero-pencil"
          end
        end

        action :remove do
          type :destroy
          action {:master_destroy, :destroy}
          confirm "Remove this post?"
          visible :active
          restricted true

          ui do
            label "Remove"
            icon "hero-x-mark"
          end
        end

        dropdown :more_actions do
          ui do
            label "More"
            icon "hero-ellipsis-vertical"
          end

          action :duplicate do
            type :event
            event :duplicate

            ui do
              label "Duplicate"
              icon "hero-document-duplicate"
            end
          end

          separator label: "Danger Zone"

          action :force_delete do
            type :event
            event :force_delete
            confirm "This will permanently delete the post. Are you sure?"
            restricted true

            ui do
              label "Force Delete"
              icon "hero-exclamation-triangle"
              class "text-red-600"
            end
          end
        end
      end

      row do
        event "show"
        selectable true

        class do
          possible ["bg-yellow-50", "bg-red-50", "bg-green-50"]

          apply fn record ->
            cond do
              record.status == :archived -> "bg-red-50"
              record.is_featured -> "bg-yellow-50"
              true -> nil
            end
          end
        end
      end

      bulk_actions do
        enabled true

        action :bulk_delete do
          confirm "Delete {count} selected posts?"
          event :bulk_delete
          payload fn ids -> %{ids: MapSet.to_list(ids)} end
          restricted true

          ui do
            label "Delete Selected"
            icon "hero-trash"
            class "text-red-600"
            extra %{destructive: true}
          end
        end

        action :bulk_archive do
          confirm true
          event :bulk_archive
          restricted false

          ui do
            label "Archive Selected"
            icon "hero-archive-box"
          end
        end

        action :bulk_publish do
          confirm false
          event :bulk_publish

          ui do
            label "Publish Selected"
            icon "hero-check-circle"
            class "text-green-600"
          end
        end
      end

      pagination do
        type :numbered
        page_size 20
        page_size_options [10, 20, 50, 100]

        ui do
          load_more_label "Load More Posts"
          loading_text "Loading posts..."
          show_total true
        end
      end

      realtime do
        enabled true
        prefix "complex_posts"
      end

      empty_state do
        message "No posts found"
        icon "hero-document-text"
        action_label "Create Post"
        action_path "/admin/complex-posts/new"
        action_icon "hero-plus"
      end

      error_state do
        message "Failed to load posts"
        icon "hero-exclamation-circle"
        retry_label "Try Again"
      end

      presentation do
        template MishkaGervaz.Table.Templates.Table
        switchable_templates []
        template_options striped: true, bordered: false, hoverable: true
        features [:sort, :filter, :select, :paginate]
        ui_adapter MishkaGervaz.UIAdapters.Tailwind
        ui_adapter_opts []

        theme do
          header_class "bg-gray-100 text-gray-700"
          row_class "border-b"
          border_class "border-gray-200"
          extra %{compact: false}
        end

        responsive do
          hide_on_mobile [:content, :view_count]
          hide_on_tablet [:content]
          mobile_layout :cards
        end
      end

      refresh do
        enabled true
        interval 30_000
        pause_on_interaction true
        show_indicator true
        pause_on_blur true
      end

      url_sync do
        enabled true
        params [:filters, :sort, :page, :search]
        prefix "posts"
        preserve_params :all
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
    read :master_read
    read :tenant_read
    read :master_get
    read :master_archived
    read :archived
    read :master_get_archived
    read :get_archived
    destroy :master_destroy
    update :master_unarchive, accept: []
    update :unarchive, accept: []
    destroy :master_permanent_destroy
    destroy :permanent_destroy
    update :publish, accept: []
    update :master_feature, accept: []
    update :feature, accept: []
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
      default :draft
      public? true
      constraints one_of: [:draft, :published, :archived]
    end

    attribute :view_count, :integer do
      default 0
      public? true
    end

    attribute :rating, :decimal do
      public? true
    end

    attribute :is_featured, :boolean do
      default false
      public? true
    end

    attribute :published_at, :utc_datetime do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, MishkaGervaz.Test.Resources.ComplexTestUser do
      public? true
      allow_nil? true
    end
  end
end
