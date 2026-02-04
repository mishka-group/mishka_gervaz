defmodule MishkaGervaz.Test.Resources.BulkActionsResource do
  @moduledoc """
  Test resource with bulk_actions configured.
  Used to test bulk_actions validation without protocol consolidation warnings.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :bulk_actions_test
        route "/admin/bulk-actions-test"
      end

      columns do
        column :name
        column :status
      end

      bulk_actions do
        action :delete do
          confirm "Delete {count} items?"
          event :bulk_delete
          handler(:parent)
        end

        action :archive do
          event :bulk_archive
          handler(:bulk_archive_action)
        end

        action :export do
          event :bulk_export
          handler({:master_bulk_export, :tenant_bulk_export})
        end

        action :custom_fn do
          handler(fn _selected_ids, _state -> :ok end)
        end

        action :unarchive do
          type :unarchive
          confirm "Restore {count} items?"
          visible :archived
        end

        action :permanent_delete do
          type :permanent_destroy
          confirm "Permanently delete {count} items?"
          visible :archived
        end

        action :soft_delete do
          type :destroy
          confirm "Archive {count} items?"
        end

        action :notify do
          type :event
          event :bulk_notify
        end

        action :activate do
          type :update
          action {:master_activate, :activate}
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

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :archived]
      default :active
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
