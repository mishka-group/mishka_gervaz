defmodule MishkaGervaz.Test.Resources.QSearchResource do
  @moduledoc """
  A table whose search filter is named `:q`, with its filters and search synced to the URL.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :q_search
        route "/admin/q-search"
      end

      columns do
        column :title
      end

      filters do
        filter :q, :text do
          fields [:title]
        end
      end

      url_sync do
        enabled true
        params [:filters, :search]
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read
    read :master_get
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end
