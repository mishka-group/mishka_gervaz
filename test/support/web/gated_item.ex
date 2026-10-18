defmodule MishkaGervaz.Test.Web.GatedItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s table: a `:status` select filter, URL
  sync in `:bidirectional` mode, and every load passing `MishkaGervaz.Test.Web.LoadGate`.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :gated_items
        route "/items"
        stream_name :gated_items
      end

      columns do
        column :title
        column :status
      end

      filters do
        filter :status, :select do
          options [
            [value: "draft", label: "Draft"],
            [value: "published", label: "Published"]
          ]
        end
      end

      url_sync do
        enabled true
        mode :bidirectional
        params [:filters]
      end

      data_loader do
        pagination MishkaGervaz.Test.Web.LoadGate
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*]

    read :master_read do
      pagination offset?: true, countable: true
    end

    read :master_get
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :status, :string, public?: true
    create_timestamp :inserted_at
  end
end
