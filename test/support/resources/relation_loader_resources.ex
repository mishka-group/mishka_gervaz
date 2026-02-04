defmodule MishkaGervaz.Test.RelationLoader.Domain do
  @moduledoc """
  Test domain for RelationLoader pagination scenarios.
  """
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && Map.get(user, :site_id) == nil end
      pagination type: :numbered, page_size: 10
    end
  end

  resources do
    resource MishkaGervaz.Test.RelationLoader.NoPaginationResource
    resource MishkaGervaz.Test.RelationLoader.OptionalPaginationResource
    resource MishkaGervaz.Test.RelationLoader.RequiredPaginationResource
    resource MishkaGervaz.Test.RelationLoader.MultiTenantRelationResource
    resource MishkaGervaz.Test.RelationLoader.ParentResource
  end
end

# Resource WITHOUT pagination in its read action
defmodule MishkaGervaz.Test.RelationLoader.NoPaginationResource do
  @moduledoc """
  Resource with NO pagination - Ash.read returns plain list.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.RelationLoader.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:destroy, create: :*, update: :*]

    # No pagination - returns plain list
    read :read do
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :title, :string, public?: true
    create_timestamp :inserted_at
  end
end

# Resource WITH optional pagination (required?: false must be explicit)
defmodule MishkaGervaz.Test.RelationLoader.OptionalPaginationResource do
  @moduledoc """
  Resource with optional pagination - can use page: false to get plain list.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.RelationLoader.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:destroy, create: :*, update: :*]

    # Pagination enabled but OPTIONAL - must explicitly set required?: false
    read :read do
      primary? true
      pagination offset?: true, countable: true, required?: false
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :title, :string, public?: true
    create_timestamp :inserted_at
  end
end

# Resource WITH required pagination
defmodule MishkaGervaz.Test.RelationLoader.RequiredPaginationResource do
  @moduledoc """
  Resource with required pagination - MUST paginate, cannot use page: false.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.RelationLoader.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:destroy, create: :*, update: :*]

    # Pagination required - cannot use page: false
    read :read do
      primary? true
      pagination offset?: true, countable: true, required?: true
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :title, :string, public?: true
    create_timestamp :inserted_at
  end
end

# Multi-tenant resource for tenant testing
defmodule MishkaGervaz.Test.RelationLoader.MultiTenantRelationResource do
  @moduledoc """
  Resource with multitenancy for testing tenant parameter passing.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.RelationLoader.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read do
      primary? true
      pagination offset?: true, countable: true
    end
  end

  multitenancy do
    strategy :attribute
    attribute :site_id
    global? true
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :site_id, :string, public?: true
    create_timestamp :inserted_at
  end
end

# Parent resource with relation filter pointing to different pagination scenarios
defmodule MishkaGervaz.Test.RelationLoader.ParentResource do
  @moduledoc """
  Parent resource for testing relation filters.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.RelationLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :parent_items
        route "/admin/parent"
      end

      columns do
        column :name
      end

      pagination page_size: 10, type: :numbered
    end
  end

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read do
      primary? true
      pagination offset?: true, countable: true
    end

    read :master_read do
      pagination offset?: true, countable: true
    end

    read :tenant_read do
      pagination offset?: true, countable: true
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :no_pagination_id, :uuid, public?: true
    attribute :optional_pagination_id, :uuid, public?: true
    attribute :required_pagination_id, :uuid, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :no_pagination_ref, MishkaGervaz.Test.RelationLoader.NoPaginationResource do
      source_attribute :no_pagination_id
      allow_nil? true
      public? true
    end

    belongs_to :optional_pagination_ref,
               MishkaGervaz.Test.RelationLoader.OptionalPaginationResource do
      source_attribute :optional_pagination_id
      allow_nil? true
      public? true
    end

    belongs_to :required_pagination_ref,
               MishkaGervaz.Test.RelationLoader.RequiredPaginationResource do
      source_attribute :required_pagination_id
      allow_nil? true
      public? true
    end
  end
end
