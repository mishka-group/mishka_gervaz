defmodule MishkaGervaz.Test.Resources.ChromeTable do
  @moduledoc """
  Test resource for header/footer/notice declarations inside the table `layout`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :chrome_table
        route "/admin/chrome_table"
      end

      columns do
        column :name
        column :status
      end

      layout do
        header do
          title "Pages"
          description "All published and draft pages."
          icon "hero-document-text"
          class "mb-6"
          visible true
          restricted false
        end

        footer do
          content fn _state -> "Sorted by priority by default." end
          class "mt-2 text-xs"
        end

        notice :archived_warning do
          position :before_table
          type :warning
          icon "hero-archive-box"
          title "Viewing archived records"
          bind_to :archived_view
        end

        notice :no_match do
          position :empty_state
          type :info
          title "No records match your filters"
          content "Try clearing filters."
          bind_to :no_results
        end

        notice :bulk_hint do
          position :after_bulk_actions
          type :neutral
          content "rows selected"
          bind_to :has_selection
        end

        notice :read_only do
          position :table_top
          type :info
          title "Read-only access"
          visible fn state -> state.master_user? == false end
          restricted false
        end

        notice :master_only_top do
          position :table_top
          type :neutral
          content "Master-only context note."
          restricted true
        end

        notice :before_status_col do
          position {:before_column, :status}
          type :info
          content "Status decorator"
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read
    read :tenant_read
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
