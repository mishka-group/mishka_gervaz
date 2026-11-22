defmodule MishkaGervaz.Test.Web.Branch do
  @moduledoc """
  A site of `MishkaGervaz.Test.Web.LedgerItem`'s multi-tenant table: what its Site column names.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read, :destroy, create: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
  end
end

defmodule MishkaGervaz.Test.Web.LedgerItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/ledger` table: a multi-tenant list,
  each row of one site (`MishkaGervaz.Test.Web.Branch`), two rows a page, newest first. A master
  reads every site's rows, with a Site column (`ui do type :site end`) naming each row's site; a
  site's admin reads only that site's rows and gets no Site column, and no read of the sites.

  It pages with Load more read by keyset, and draws its Load more in the table's footer row
  (`load_more_at :footer`), beside the page's `table_footer` slot.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :ledger_items
        route "/ledger"
        stream_name :ledger_items
      end

      source do
        preload do
          master [:site]
        end
      end

      columns do
        default_sort inserted_at: :desc, title: :asc

        column :title

        column :site do
          source {:site, :name}

          ui do
            type :site
          end
        end
      end

      pagination do
        type :load_more
        page_size 2

        ui do
          load_more_at(:footer)
          load_more_label "Load older entries"
        end
      end
    end
  end

  multitenancy do
    strategy :attribute
    attribute :site_id
    global? true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      pagination offset?: true, keyset?: true, countable: true
    end

    read :tenant_read do
      pagination offset?: true, keyset?: true, countable: true
    end

    read :master_get
    destroy :master_destroy
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :site, MishkaGervaz.Test.Web.Branch, allow_nil?: false, public?: true
  end
end
