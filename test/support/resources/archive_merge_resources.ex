defmodule MishkaGervaz.Test.Resources.ArchiveMergeNoExt do
  @moduledoc """
  Resource without `AshArchival.Resource` extension. Even though the domain
  defines archive defaults, archive must be `nil` because AshArchival is the
  prerequisite (rule 1).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :archive_merge_no_ext
        route "/admin/archive-merge/no-ext"
      end

      columns do
        column :title
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.ArchiveMergeInheritDomain do
  @moduledoc """
  Resource with `AshArchival.Resource` and no resource-level archive block.
  Archive should fully inherit from the domain (rule 3).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    archive_related([])
  end

  mishka_gervaz do
    table do
      identity do
        name :archive_merge_inherit
        route "/admin/archive-merge/inherit"
      end

      columns do
        column :title
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
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
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.ArchiveMergeEnabledFalse do
  @moduledoc """
  Resource with `AshArchival.Resource` and an explicit `enabled false` in the
  resource archive block. Archive must be disabled even though the domain
  provides defaults (rule 4 — used during testing).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    archive_related([])
  end

  mishka_gervaz do
    table do
      identity do
        name :archive_merge_enabled_false
        route "/admin/archive-merge/enabled-false"
      end

      source do
        archive do
          enabled false
        end
      end

      columns do
        column :title
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.ArchiveMergePartial do
  @moduledoc """
  Resource overriding only `restricted` and `read_action`. Other keys must
  fall back to the domain (rule 5).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    archive_related([])
  end

  mishka_gervaz do
    table do
      identity do
        name :archive_merge_partial
        route "/admin/archive-merge/partial"
      end

      source do
        archive do
          restricted true
          read_action {:resource_master_archived, :resource_archived}
        end
      end

      columns do
        column :title
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :resource_master_archived
    read :resource_archived
    read :master_get_archived
    read :get_archived
    update :master_unarchive, accept: []
    update :unarchive, accept: []
    destroy :master_permanent_destroy
    destroy :permanent_destroy
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.ArchiveMergeAtomAction do
  @moduledoc """
  Resource using a single atom for `read_action`. The merger must treat the
  atom as the same action for master and tenant requests (rule 8).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    archive_related([])
  end

  mishka_gervaz do
    table do
      identity do
        name :archive_merge_atom
        route "/admin/archive-merge/atom"
      end

      source do
        archive do
          read_action :shared_archived
        end
      end

      columns do
        column :title
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :shared_archived
    read :master_get_archived
    read :get_archived
    update :master_unarchive, accept: []
    update :unarchive, accept: []
    destroy :master_permanent_destroy
    destroy :permanent_destroy
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
