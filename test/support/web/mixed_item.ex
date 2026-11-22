defmodule MishkaGervaz.Test.Web.MixedItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/mixed` table: a filter of every type,
  among them a relation of one value and one of several, a type of the test's own
  (`MishkaGervaz.Test.Web.MixedItem.AnyFilter`), and everything a URL may carry (filters, sort, page,
  page size, search, template and the page's own params) synced in `:bidirectional` mode under the
  prefix `mixed`.
  """

  defmodule AnyFilter do
    @moduledoc "A filter type that takes a text, a list or a map, and narrows nothing."

    @behaviour MishkaGervaz.Table.Behaviours.FilterType
    use Phoenix.Component

    @impl true
    def render_input(_filter, value, _ui) do
      assigns = %{value: inspect(value)}
      ~H[<span data-role="any-filter">{@value}</span>]
    end

    @impl true
    def parse_value(value, _filter), do: value

    @impl true
    def build_query(query, _field, _value), do: query

    @impl true
    def build_query(query, _field, _value, _filter), do: query
  end

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :mixed_items
        route "/mixed"
        stream_name :mixed_items
      end

      columns do
        default_sort title: :asc

        column :title do
          sortable true
        end

        column :status
      end

      filters do
        filter :search, :text do
          fields [:title]
        end

        filter :note, :text do
          source :title
        end

        filter :status, :select do
          options [{"Draft", "draft"}, {"Published", "published"}]
        end

        filter :pinned, :boolean
        filter :size, :number
        filter :day, :date
        filter :period, :date_range, source: :inserted_at

        filter :owner, :relation do
          source :id
          resource MishkaGervaz.Test.Web.GatedItem
          display_field :title
          load_action :read
          mode :search
        end

        filter :owners, :relation do
          source :id
          resource MishkaGervaz.Test.Web.GatedItem
          display_field :title
          load_action :read
          mode :search_multi
        end

        filter :shape, MishkaGervaz.Test.Web.MixedItem.AnyFilter, virtual: true
      end

      presentation do
        switchable_templates [
          MishkaGervaz.Table.Templates.Table,
          MishkaGervaz.Test.Web.KeptRows
        ]
      end

      url_sync do
        enabled true
        mode :bidirectional
        prefix "mixed"
        params [:filters, :sort, :page, :page_size, :search, :template]
        preserve_params :all
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
    attribute :pinned, :boolean, public?: true
    attribute :size, :integer, public?: true
    attribute :day, :date, public?: true
    create_timestamp :inserted_at, public?: true
  end
end
