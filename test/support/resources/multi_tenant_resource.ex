defmodule MishkaGervaz.Test.Resources.MultiTenantResource do
  @moduledoc """
  Test resource with multitenancy enabled.
  Used to test action resolution for multi-tenant resources.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.ActionResolutionDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :multi_tenant_test
        route "/admin/multi-tenant"
      end

      columns do
        column :name
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :master_read
    read :tenant_read
    read :master_get
    destroy :master_destroy
  end

  multitenancy do
    strategy :attribute
    attribute :site_id
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :site_id, :uuid do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
