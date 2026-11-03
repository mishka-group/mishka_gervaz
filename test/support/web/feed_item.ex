defmodule MishkaGervaz.Test.Web.FeedItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/feed` table: a list sorted by title
  that loads more 20 rows at a time and keeps no count, with its page synced to the URL in
  `:bidirectional` mode.

  Keeping no count, the table knows no last page, so a page event goes to the page it names. Its
  read reads at most 15 rows at a time (`max_page_size 15`), fewer than a page holds.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :feed_items
        route "/feed"
        stream_name :feed_items
      end

      columns do
        default_sort title: :asc

        column :title
      end

      pagination do
        type :load_more

        ui do
          show_total false
        end
      end

      url_sync do
        enabled true
        mode :bidirectional
        params [:page]
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*]

    read :master_read do
      pagination offset?: true, max_page_size: 15
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
