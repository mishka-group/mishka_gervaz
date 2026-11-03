defmodule MishkaGervaz.Test.Web.KeptItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/kept` table: a list that loads more two
  rows at a time and keeps the rows it has loaded (`keep_loaded_records`), drawn by the stock
  `MishkaGervaz.Table.Templates.Table` or by `MishkaGervaz.Test.Web.KeptRows`, which draws those
  kept rows. Its template and page are synced to the URL in `:bidirectional` mode.

  Its read reads at most three rows at a time (`max_page_size 3`), fewer than a table that has
  loaded two pages keeps.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :kept_items
        route "/kept"
        stream_name :kept_items
      end

      columns do
        default_sort title: :asc

        column :title
      end

      presentation do
        switchable_templates [
          MishkaGervaz.Table.Templates.Table,
          MishkaGervaz.Test.Web.KeptRows
        ]

        keep_loaded_records true
      end

      pagination do
        type :load_more
        page_size 2
      end

      url_sync do
        enabled true
        mode :bidirectional
        params [:page, :template]
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      pagination offset?: true, countable: true, max_page_size: 3
    end

    read :master_get
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end
