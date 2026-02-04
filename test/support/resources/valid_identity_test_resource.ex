defmodule MishkaGervaz.Test.Resources.ValidIdentityTestResource do
  @moduledoc """
  Pre-compiled resource for testing valid identity configuration.
  Used by ValidateIdentityTest to avoid runtime module creation warnings.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :valid_table
        route "/admin/valid"
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
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end
  end
end
