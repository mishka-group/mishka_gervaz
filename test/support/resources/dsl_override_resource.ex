defmodule MishkaGervaz.Test.Resources.DslOverrideResource do
  @moduledoc """
  Test resource that overrides domain action defaults with DSL config.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.ActionResolutionDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :dsl_override_test
        route "/admin/dsl-override"
      end

      source do
        actions do
          read {:custom_master, :custom_tenant}
          get {:custom_master_get, :custom_get}
          destroy {:custom_master_destroy, :custom_destroy}
        end
      end

      columns do
        column :name
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :custom_master
    read :custom_tenant
    read :custom_master_get
    read :custom_get
    destroy :custom_master_destroy
    destroy :custom_destroy
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
