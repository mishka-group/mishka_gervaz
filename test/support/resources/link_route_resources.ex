defmodule MishkaGervaz.Test.Resources.LinkRoute do
  @moduledoc """
  A table whose `:link` row actions build their addresses from the table's route.

  `:edit`, `:show`, `:edit_link` and `:show_link` declare no `path`, so each is built from the
  route, its `:site_id` param filled in from the state; `:open` gives its own `path`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :link_route
        route "/admin/sites/:site_id/products"
      end

      columns do
        column :title
      end

      row_actions do
        action :edit do
          type :link
        end

        action :show do
          type :link
        end

        action :edit_link do
          type :link
        end

        action :show_link do
          type :link
        end

        action :open do
          type :link
          path fn record -> "/shop/products/#{record.id}" end
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_get
    read :master_read
    read :tenant_read
  end
end

defmodule MishkaGervaz.Test.Resources.InPlaceEdit do
  @moduledoc """
  A table that edits in place: `:edit` opens the form on the same page and `:show` is an event,
  the two styles that are not links.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  alias Phoenix.LiveView.JS

  mishka_gervaz do
    table do
      identity do
        name :in_place_edit
        route "/admin/in-place"
      end

      columns do
        column :title
      end

      row_actions do
        action :edit do
          type :edit
          js fn _record -> JS.show(to: "#in-place-form-modal") end
        end

        action :show do
          type :event
          event :show_details
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_get
    read :master_read
    read :tenant_read
  end
end
