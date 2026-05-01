defmodule MishkaGervaz.Test.Resources.ChromeForm do
  @moduledoc """
  Test resource for header/footer/notice declarations inside the form `layout`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :chrome_form_table
        route "/admin/chrome"
      end

      columns do
        column :name
      end
    end

    form do
      identity do
        name :chrome_form
        route "/admin/chrome"
      end

      source do
        master_check fn user -> user && user.role == :admin end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :name, :text do
          required true
        end

        field :description, :textarea
      end

      groups do
        group :basic do
          fields [:name, :description]

          ui do
            label "Basic"
          end
        end
      end

      layout do
        columns 1
        mode :standard

        header do
          title "Account Permissions"
          description "Configure what this account can access."
          icon "hero-shield-check"
          class "mb-6"
          visible true
          restricted false
        end

        footer do
          content fn _state -> "Last updated externally" end
          class "mt-4 text-xs"
        end

        notice :read_only_banner do
          position :before_fields
          type :warning
          title "Read-Only Access"
          content "Your role can view but not modify these settings."
          icon "hero-lock-closed"
          dismissible false
          visible fn state -> state.master_user? == false end
          restricted false

          ui do
            class "border-amber-300"
          end
        end

        notice :validation_summary do
          position :form_top
          type :error
          bind_to :validation
          title "Please fix the errors below"
        end

        notice :after_basic_note do
          position {:after_group, :basic}
          type :info
          content "These settings power the public profile."
        end

        notice :master_only do
          position :before_submit
          type :neutral
          content "Master-only context note."
          restricted true
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

    attribute :description, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
