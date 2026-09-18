defmodule MishkaGervaz.Test.Resources.AuthorizedWriteResource do
  @moduledoc """
  Test resource whose every write action carries `MishkaGervaz.Test.RequireAuthorization`, so a write
  run with authorization off is visible: the validation stands aside and a non-admin actor gets
  through.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    archive_related([])
    exclude_read_actions([:archived, :get_archived, :master_archived, :master_get_archived])
    exclude_destroy_actions([:permanent_destroy, :master_permanent_destroy])
  end

  mishka_gervaz do
    table do
      identity do
        name :authorized_write_items
        route "/admin/authorized-write"
      end

      source do
        actions do
          read {:master_read, :read}
          get {:master_get, :read}
          destroy {:master_destroy, :destroy}
        end

        preload do
          always []
        end

        archive do
          enabled true
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
      end

      pagination page_size: 20, type: :numbered
    end
  end

  actions do
    defaults [:read, create: :*, update: :*]

    read :master_read
    read :master_get
    read :archived
    read :get_archived
    read :master_archived
    read :master_get_archived

    destroy :destroy do
      primary? true
      require_atomic? false
      validate MishkaGervaz.Test.RequireAuthorization
    end

    destroy :master_destroy do
      require_atomic? false
      validate MishkaGervaz.Test.RequireAuthorization
    end

    destroy :permanent_destroy do
      require_atomic? false
      validate MishkaGervaz.Test.RequireAuthorization
    end

    destroy :master_permanent_destroy do
      require_atomic? false
      validate MishkaGervaz.Test.RequireAuthorization
    end

    update :unarchive do
      accept []
      require_atomic? false
      validate MishkaGervaz.Test.RequireAuthorization
      change set_attribute(:archived_at, nil)
    end

    update :master_unarchive do
      accept []
      require_atomic? false
      validate MishkaGervaz.Test.RequireAuthorization
      change set_attribute(:archived_at, nil)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
