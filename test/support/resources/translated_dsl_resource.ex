defmodule MishkaGervaz.Test.Resources.TranslatedDsl do
  @moduledoc """
  A resource whose `mishka_gervaz` DSL holds plain strings, marked with `dgettext_noop`, for the
  tests that read them in another language.

  Every string-only option the library draws appears once: column, filter and field labels, a
  badge's labels, a select's prompt and options, a placeholder, a row action's confirm and the
  separator of a dropdown, bulk actions, the empty and error states, pagination, and the header,
  footer and notices of the table and of the form. `:slug`, `:publish`, `:archive_all` and
  `:publish_all` declare no label, so they are drawn by their humanized names.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  use MishkaGervaz.Messages

  mishka_gervaz do
    table do
      identity do
        name :translated_dsl
        route "/admin/translated-dsl"
      end

      columns do
        column :title do
          label dgettext_noop("mishka_gervaz", "Heading")
        end

        column :slug

        column :status do
          ui do
            type :badge

            extra %{
              labels: %{
                "published" => dgettext_noop("mishka_gervaz", "Published"),
                "draft" => dgettext_noop("mishka_gervaz", "Draft")
              }
            }
          end
        end

        column :featured do
          ui do
            type :boolean

            extra %{
              true_label: dgettext_noop("mishka_gervaz", "Featured"),
              false_label: dgettext_noop("mishka_gervaz", "Ordinary")
            }
          end
        end
      end

      filters do
        filter :search, :text do
          fields [:title]

          ui do
            label dgettext_noop("mishka_gervaz", "Find posts")
            placeholder dgettext_noop("mishka_gervaz", "Search posts")
          end
        end

        filter :status, :select do
          options [
            {dgettext_noop("mishka_gervaz", "Draft"), :draft},
            {dgettext_noop("mishka_gervaz", "Published"), :published}
          ]

          ui do
            label dgettext_noop("mishka_gervaz", "Status")
            prompt dgettext_noop("mishka_gervaz", "Pick a status")
          end
        end

        filter :featured, :boolean do
          ui do
            label dgettext_noop("mishka_gervaz", "Featured only")
          end
        end
      end

      row_actions do
        actions_layout do
          inline [:publish, :remove, :wipe]
          dropdown [:more]
        end

        action :publish do
          type :event
          event :publish
          visible true
        end

        action :remove do
          type :destroy
          confirm dgettext_noop("mishka_gervaz", "Delete this draft?")
          visible true
        end

        action :wipe do
          type :permanent_destroy
          confirm fn record -> "Wipe #{record.title} for good?" end
          visible true
        end

        dropdown :more do
          ui do
            label dgettext_noop("mishka_gervaz", "More")
          end

          action :duplicate do
            type :event
            event :duplicate
            visible true
          end

          separator label: dgettext_noop("mishka_gervaz", "Danger zone")

          action :discard do
            type :event
            event :discard
            visible true
          end
        end
      end

      bulk_actions do
        action :archive_all do
          event :archive_all
          confirm dgettext_noop("mishka_gervaz", "Archive the selected posts?")
        end

        action :publish_all do
          event :publish_all
        end
      end

      pagination do
        type :numbered
        page_size 10

        ui do
          prev_label dgettext_noop("mishka_gervaz", "Earlier")
          next_label dgettext_noop("mishka_gervaz", "Later")
          page_info_format dgettext_noop("mishka_gervaz", "Page {page} of {total}")
        end
      end

      empty_state do
        message dgettext_noop("mishka_gervaz", "Nothing here yet")
        action_label dgettext_noop("mishka_gervaz", "Add one")
        action_path "/admin/translated-dsl/new"
      end

      error_state do
        message dgettext_noop("mishka_gervaz", "Could not load the posts")
        retry_label dgettext_noop("mishka_gervaz", "Try again")
      end

      layout do
        header do
          title dgettext_noop("mishka_gervaz", "All posts")
          description dgettext_noop("mishka_gervaz", "Everything that was ever written.")
        end

        footer do
          content dgettext_noop("mishka_gervaz", "Sorted by date.")
        end

        notice :hint do
          position :before_table
          type :info
          title dgettext_noop("mishka_gervaz", "Heads up")
          content dgettext_noop("mishka_gervaz", "Drafts are hidden from visitors.")
        end
      end
    end

    form do
      identity do
        name :translated_dsl_form
        route "/admin/translated-dsl"
      end

      source do
        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text do
          ui do
            label dgettext_noop("mishka_gervaz", "Post title")
            placeholder dgettext_noop("mishka_gervaz", "Type a title")
            description dgettext_noop("mishka_gervaz", "Shown as the page heading.")
          end
        end

        field :slug, :text

        field :status, :select do
          options [
            {dgettext_noop("mishka_gervaz", "Draft"), :draft},
            {dgettext_noop("mishka_gervaz", "Published"), :published}
          ]

          ui do
            label dgettext_noop("mishka_gervaz", "Status")
          end
        end
      end

      groups do
        group :basic do
          fields [:title, :slug, :status]

          ui do
            label dgettext_noop("mishka_gervaz", "Basic")
          end
        end
      end

      layout do
        columns 1
        mode :standard

        header do
          title dgettext_noop("mishka_gervaz", "Write a post")
          description dgettext_noop("mishka_gervaz", "Fill in the details below.")
        end

        footer do
          content dgettext_noop("mishka_gervaz", "Saved posts are published at once.")
        end

        notice :read_only do
          position :before_groups
          type :warning
          title dgettext_noop("mishka_gervaz", "Careful")
          content dgettext_noop("mishka_gervaz", "Changes are visible to everyone.")
        end
      end

      submit do
        create label: dgettext_noop("mishka_gervaz", "Save the post")
        cancel label: dgettext_noop("mishka_gervaz", "Never mind")
      end
    end
  end

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :slug, :string, public?: true

    attribute :status, :atom do
      constraints one_of: [:draft, :published]
      public? true
    end

    attribute :featured, :boolean, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_get
    read :master_read
    read :tenant_read
    destroy :master_destroy
    create :master_create, accept: :*
    update :master_update, accept: :*
  end
end
