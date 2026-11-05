defmodule MishkaGervaz.Test.Web.PlainItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/plain` table: a list sorted by title
  that loads more four rows at a time and keeps no rows it has loaded, so its rows live only in the
  stream. Each row has a Delete action; its rows can be picked, and its Wipe bulk action destroys
  the picked ones. Its page is synced to the URL in `:bidirectional` mode.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :plain_items
        route "/plain"
        stream_name :plain_items
      end

      columns do
        default_sort title: :asc

        column :title
      end

      pagination do
        type :load_more
        page_size 4
      end

      row do
        selectable true
      end

      row_actions do
        action :delete, type: :destroy
      end

      bulk_actions do
        action :wipe, type: :destroy
      end

      url_sync do
        enabled true
        mode :bidirectional
        params [:page]
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      pagination offset?: true, countable: true
    end

    read :master_get
    read :tenant_read
    destroy :master_destroy
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end
