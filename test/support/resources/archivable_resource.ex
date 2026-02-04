defmodule MishkaGervaz.Test.Resources.ArchivableResource do
  @moduledoc """
  Test resource with AshArchival for archive functionality testing.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    # AshArchival configuration
    archive_related []
  end

  mishka_gervaz do
    table do
      identity do
        name :archivable_items
        route "/admin/archivable"
      end

      source do
        actions do
          read {:master_read, :tenant_read}
          get {:master_get, :read}
          destroy {:master_destroy, :destroy}
        end

        preload do
          always []
        end

        # Archive section - requires AshArchival.Resource
        # Uses inline action options to avoid path conflicts with source.actions
        archive do
          enabled true
          restricted true
          read_action {:master_archived, :archived}
          get_action {:master_get_archived, :get_archived}
          restore_action {:master_unarchive, :unarchive}
          destroy_action {:master_permanent_destroy, :permanent_destroy}
        end
      end

      columns do
        column :title do
          sortable true
          searchable true
        end

        column :status do
          sortable true
        end
      end

      filters do
        filter :search, :text do
          fields [:title]
        end
      end

      pagination page_size: 20, type: :numbered
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read
    read :tenant_read
    read :master_get
    read :master_destroy
    read :master_archived
    read :archived
    read :master_get_archived
    read :get_archived
    update :master_unarchive, accept: []
    update :unarchive, accept: []
    destroy :master_permanent_destroy
    destroy :permanent_destroy
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
