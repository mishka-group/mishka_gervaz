defmodule MishkaGervaz.Test.Resources.InfiniteScrollResource do
  @moduledoc """
  Test resource with `pagination type: :infinite` for testing the
  phx-viewport-bottom binding rendered on the streaming `<tbody>`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :infinite_scroll
        route "/admin/infinite-scroll"
      end

      columns do
        column :name
      end

      filters do
        filter :name, :text
      end

      pagination type: :infinite, page_size: 20
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :master_read
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.NumberedScrollResource do
  @moduledoc """
  Counterpart of InfiniteScrollResource — same shape, but `pagination type:
  :numbered`. Used as the negative case for the phx-viewport-bottom binding test.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :numbered_scroll
        route "/admin/numbered-scroll"
      end

      columns do
        column :name
      end

      filters do
        filter :name, :text
      end

      pagination type: :numbered, page_size: 20
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    read :master_read
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
