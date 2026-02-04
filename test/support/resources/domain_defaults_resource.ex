defmodule MishkaGervaz.Test.Resources.DomainDefaultsResource do
  @moduledoc """
  Test resource that uses domain defaults for actions (no source section).
  Used to test domain-level action inheritance.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.ActionResolutionDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :domain_defaults_test
        route "/admin/domain-defaults"
      end

      columns do
        column :name
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :domain_master_read
    read :domain_tenant_read
    read :domain_master_get
    read :domain_get
    destroy :domain_master_destroy
    destroy :domain_destroy
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
