defmodule MishkaGervaz.Test.Resources.MinimalResource do
  @moduledoc """
  Minimal test resource with only required DSL options.
  Used to test defaults and minimal configuration.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :minimal
        route "/admin/minimal"
      end

      columns do
        column :name
        column :inserted_at
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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
