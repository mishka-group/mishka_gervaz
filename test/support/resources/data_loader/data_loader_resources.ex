defmodule MishkaGervaz.Test.DataLoader.Domain do
  @moduledoc false
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
    resource MishkaGervaz.Test.DataLoader.BasicResource
    resource MishkaGervaz.Test.DataLoader.InfinitePaginationResource
    resource MishkaGervaz.Test.DataLoader.FilterableResource
    resource MishkaGervaz.Test.DataLoader.SortableResource
    resource MishkaGervaz.Test.DataLoader.HooksResource
    resource MishkaGervaz.Test.DataLoader.UrlSyncResource
    resource MishkaGervaz.Test.DataLoader.MultiTenantResource
    resource MishkaGervaz.Test.DataLoader.ArchivableResource
  end
end

defmodule MishkaGervaz.Test.DataLoader.BasicResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :basic_items
        route "/admin/basic"
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

      pagination page_size: 5, type: :numbered
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.DataLoader.InfinitePaginationResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :infinite_items
        route "/admin/infinite"
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

      pagination page_size: 3, type: :infinite
    end
  end

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read do
      primary? true
      pagination offset?: true
    end

    read :master_read do
      pagination offset?: true
    end

    read :tenant_read do
      pagination offset?: true
    end

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.DataLoader.FilterableResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :filterable_items
        route "/admin/filterable"
      end

      columns do
        column :title do
          sortable true
          searchable true
        end

        column :category do
          sortable true
        end

        column :status do
          sortable true
        end

        column :priority
      end

      filters do
        filter :search, :text do
          fields [:title]
        end

        filter :category, :select do
          options [
            [value: "tech", label: "Technology"],
            [value: "news", label: "News"],
            [value: "sports", label: "Sports"]
          ]
        end

        filter :status, :select do
          options [
            [value: "draft", label: "Draft"],
            [value: "published", label: "Published"],
            [value: "archived", label: "Archived"]
          ]
        end

        filter :priority, :select do
          options [
            [value: "low", label: "Low"],
            [value: "medium", label: "Medium"],
            [value: "high", label: "High"]
          ]
        end
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :category, :string, public?: true
    attribute :status, :string, default: "draft", public?: true
    attribute :priority, :string, default: "medium", public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.DataLoader.SortableResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :sortable_items
        route "/admin/sortable"
      end

      columns do
        column :name do
          sortable true
        end

        column :score do
          sortable true
        end

        column :rank do
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :score, :integer, default: 0, public?: true
    attribute :rank, :integer, default: 1, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.DataLoader.HooksResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :hooks_items
        route "/admin/hooks"
      end

      columns do
        column :name do
          sortable true
        end

        column :active
      end

      filters do
        filter :search, :text do
          fields [:name]
        end
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :active, :boolean, default: true, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.DataLoader.UrlSyncResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :url_sync_items
        route "/admin/url-sync"
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

      url_sync do
        enabled true
        mode :bidirectional
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.DataLoader.MultiTenantResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :multi_tenant_items
        route "/admin/multi-tenant"
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

    read :get
    read :master_get
    read :tenant_get
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

defmodule MishkaGervaz.Test.DataLoader.ArchivableResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.Domain,
    extensions: [AshArchival.Resource, MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  archive do
    archive_related([])
  end

  mishka_gervaz do
    table do
      identity do
        name :archivable_items
        route "/admin/archivable"
      end

      source do
        archive do
          enabled true
          read_action {:master_archived, :archived}
          get_action {:master_get_archived, :get_archived}
          restore_action {:master_unarchive, :unarchive}
          destroy_action {:master_permanent_destroy, :permanent_destroy}
        end
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

    read :master_archived do
      pagination offset?: true, countable: true

      filter expr(not is_nil(archived_at))
    end

    read :archived do
      pagination offset?: true, countable: true

      filter expr(not is_nil(archived_at))
    end

    read :master_get_archived
    read :get_archived

    read :get
    read :master_get
    read :tenant_get

    update :master_unarchive do
      accept []
      change set_attribute(:archived_at, nil)
    end

    update :unarchive do
      accept []
      change set_attribute(:archived_at, nil)
    end

    destroy :master_permanent_destroy
    destroy :permanent_destroy
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

# Custom DataLoader sub-builders for testing DSL overrides
defmodule MishkaGervaz.Test.DataLoader.CustomPaginationHandler do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.PaginationHandler

  # Track calls for testing
  def load_page(state, query, page, action, tenant) do
    # Add a marker to results so we can verify this module was used
    Process.put(:custom_pagination_called, true)
    Process.put(:custom_pagination_page, page)
    super(state, query, page, action, tenant)
  end

  def calculate_total_pages(0, _page_size), do: 1

  def calculate_total_pages(total_count, page_size) do
    # Custom implementation - add 1 to regular calculation
    ceil(total_count / page_size)
  end
end

defmodule MishkaGervaz.Test.DataLoader.CustomQueryBuilder do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.QueryBuilder

  def build_query(state) do
    Process.put(:custom_query_builder_called, true)
    super(state)
  end
end

defmodule MishkaGervaz.Test.DataLoader.CustomFilterParser do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.FilterParser

  def parse_filter_values(raw_values, filters) do
    Process.put(:custom_filter_parser_called, true)
    super(raw_values, filters)
  end
end

defmodule MishkaGervaz.Test.DataLoader.CustomTenantResolver do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.TenantResolver

  def get_tenant(state) do
    Process.put(:custom_tenant_resolver_called, true)
    super(state)
  end
end

defmodule MishkaGervaz.Test.DataLoader.CustomHookRunner do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.HookRunner

  def run_hook(hooks, hook_name, args) do
    Process.put(:custom_hook_runner_called, true)
    Process.put(:custom_hook_name, hook_name)
    super(hooks, hook_name, args)
  end
end

defmodule MishkaGervaz.Test.DataLoader.CustomRelationLoader do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.RelationLoader

  def load_options(filter, state, opts \\ []) do
    Process.put(:custom_relation_loader_called, true)
    super(filter, state, opts)
  end
end

# Custom DataLoader that overrides the whole module
defmodule MishkaGervaz.Test.DataLoader.CustomDataLoaderModule do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader

  def load_async(socket, state, opts \\ []) do
    Process.put(:custom_data_loader_module_called, true)
    super(socket, state, opts)
  end
end

# Domain for custom DataLoader resources
defmodule MishkaGervaz.Test.DataLoader.CustomDomain do
  @moduledoc false
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
    resource MishkaGervaz.Test.DataLoader.CustomPaginationResource
    resource MishkaGervaz.Test.DataLoader.CustomQueryResource
    resource MishkaGervaz.Test.DataLoader.CustomFullResource
    resource MishkaGervaz.Test.DataLoader.CustomModuleResource
  end
end

# Resource with custom pagination handler via DSL
defmodule MishkaGervaz.Test.DataLoader.CustomPaginationResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.CustomDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :custom_pagination_items
        route "/admin/custom-pagination"
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

      data_loader do
        pagination MishkaGervaz.Test.DataLoader.CustomPaginationHandler
      end

      pagination page_size: 5, type: :numbered
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

# Resource with custom query builder via DSL
defmodule MishkaGervaz.Test.DataLoader.CustomQueryResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.CustomDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :custom_query_items
        route "/admin/custom-query"
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

      data_loader do
        query MishkaGervaz.Test.DataLoader.CustomQueryBuilder
      end

      pagination page_size: 5, type: :numbered
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

# Resource with multiple custom sub-builders
defmodule MishkaGervaz.Test.DataLoader.CustomFullResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.CustomDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :custom_full_items
        route "/admin/custom-full"
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

      data_loader do
        query MishkaGervaz.Test.DataLoader.CustomQueryBuilder
        filter_parser MishkaGervaz.Test.DataLoader.CustomFilterParser
        pagination MishkaGervaz.Test.DataLoader.CustomPaginationHandler
        tenant MishkaGervaz.Test.DataLoader.CustomTenantResolver
        hooks MishkaGervaz.Test.DataLoader.CustomHookRunner
        relation MishkaGervaz.Test.DataLoader.CustomRelationLoader
      end

      pagination page_size: 5, type: :numbered
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

# Resource with custom module (complete DataLoader override) - using positional arg
defmodule MishkaGervaz.Test.DataLoader.CustomModuleResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.DataLoader.CustomDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :custom_module_items
        route "/admin/custom-module"
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

      data_loader MishkaGervaz.Test.DataLoader.CustomDataLoaderModule

      pagination page_size: 5, type: :numbered
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

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end
