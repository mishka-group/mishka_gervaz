defmodule MishkaGervaz.Test.Resources.DynamicOptionsResource do
  @moduledoc """
  Test resource for dynamic (function-based) filter options.

  Covers three select filter scenarios:
  - `:category` — explicit static list options
  - `:language` — runtime callback function (fn -> [...] end)
  - `:priority` — no options, auto-detected from attribute one_of constraint
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :dynamic_items
        route "/admin/dynamic-items"
      end

      columns do
        column :name do
          sortable true
        end

        column :language do
          sortable true
        end

        column :category do
          sortable true
        end

        column :priority do
          sortable true
        end
      end

      filters do
        filter :search, :text do
          fields [:name]
        end

        filter :language, :select do
          options fn ->
            [{"English", "en"}, {"Persian", "fa"}, {"Arabic", "ar"}]
          end
        end

        filter :category, :select do
          options [
            {"Tech", "tech"},
            {"Science", "science"}
          ]
        end

        filter :priority, :select do
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :language, :string do
      public? true
    end

    attribute :category, :string do
      public? true
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
