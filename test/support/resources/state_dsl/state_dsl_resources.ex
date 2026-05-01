defmodule MishkaGervaz.Test.StateDsl.Domain do
  @moduledoc false
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && Map.get(user, :site_id) == nil end

      actions do
        read {:master_read, :read}
        get {:master_get, :read}
        destroy {:master_destroy, :destroy}
      end
    end
  end

  resources do
    resource MishkaGervaz.Test.StateDsl.ColumnOverrideResource
    resource MishkaGervaz.Test.StateDsl.FilterOverrideResource
    resource MishkaGervaz.Test.StateDsl.ActionOverrideResource
    resource MishkaGervaz.Test.StateDsl.PresentationOverrideResource
    resource MishkaGervaz.Test.StateDsl.UrlSyncOverrideResource
    resource MishkaGervaz.Test.StateDsl.AccessOverrideResource
    resource MishkaGervaz.Test.StateDsl.AllBuildersOverrideResource
    resource MishkaGervaz.Test.StateDsl.WholeStateOverrideResource
  end
end

defmodule MishkaGervaz.Test.StateDsl.ColumnOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :column_override_items
        route "/admin/column-override"
      end

      columns do
        column :name do
          sortable true
        end

        column :inserted_at do
          sortable true
        end
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      state do
        column MishkaGervaz.Test.StateDsl.CustomColumnBuilder
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.FilterOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :filter_override_items
        route "/admin/filter-override"
      end

      columns do
        column :name
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      state do
        filter MishkaGervaz.Test.StateDsl.CustomFilterBuilder
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.ActionOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :action_override_items
        route "/admin/action-override"
      end

      columns do
        column :name
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      row_actions do
        action :show do
          type :link
          path fn record -> "/items/#{record.id}" end
        end
      end

      bulk_actions do
        action :delete do
          confirm "Delete selected?"
        end
      end

      state do
        action MishkaGervaz.Test.StateDsl.CustomActionBuilder
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.PresentationOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :presentation_override_items
        route "/admin/presentation-override"
      end

      columns do
        column :name
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      state do
        presentation MishkaGervaz.Test.StateDsl.CustomPresentation
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.UrlSyncOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :url_sync_override_items
        route "/admin/url-sync-override"
      end

      columns do
        column :name
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      url_sync do
        enabled true
        mode :bidirectional
      end

      state do
        url_sync MishkaGervaz.Test.StateDsl.CustomUrlSync
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.AccessOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :access_override_items
        route "/admin/access-override"
      end

      columns do
        column :name
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      state do
        access MishkaGervaz.Test.StateDsl.CustomAccess
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :site_id, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.AllBuildersOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :all_builders_override_items
        route "/admin/all-builders-override"
      end

      columns do
        column :name do
          sortable true
        end
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      row_actions do
        action :show do
          type :link
          path fn record -> "/items/#{record.id}" end
        end
      end

      bulk_actions do
        action :delete do
          confirm "Delete selected?"
        end
      end

      url_sync do
        enabled true
        mode :bidirectional
      end

      state do
        column MishkaGervaz.Test.StateDsl.CustomColumnBuilder
        filter MishkaGervaz.Test.StateDsl.CustomFilterBuilder
        action MishkaGervaz.Test.StateDsl.CustomActionBuilder
        presentation MishkaGervaz.Test.StateDsl.CustomPresentation
        url_sync MishkaGervaz.Test.StateDsl.CustomUrlSync
        access MishkaGervaz.Test.StateDsl.CustomAccess
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :site_id, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.StateDsl.WholeStateOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.StateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :whole_state_override_items
        route "/admin/whole-state-override"
      end

      columns do
        column :name do
          sortable true
        end
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
      end

      state do
        module MishkaGervaz.Test.StateDsl.CustomWholeState
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    create_timestamp :inserted_at
  end
end
