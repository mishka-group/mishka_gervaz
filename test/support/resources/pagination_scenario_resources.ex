defmodule MishkaGervaz.Test.Resources.PaginationScenarios do
  @moduledoc """
  Test resources for pagination merge scenarios.
  """

  # Domain with pagination type: :numbered
  defmodule ScenarioDomain do
    use Ash.Domain,
      extensions: [MishkaGervaz.Domain],
      validate_config_inclusion?: false

    mishka_gervaz do
      table do
        actor_key :current_user
        master_check fn user -> user && user.role == :admin end
        pagination type: :numbered, page_size: 30

        actions do
          read {:master_read, :read}
          get {:master_get, :read}
          destroy {:master_destroy, :destroy}
        end
      end
    end

    resources do
      resource MishkaGervaz.Test.Resources.PaginationScenarios.Scenario7Resource
      resource MishkaGervaz.Test.Resources.PaginationScenarios.Scenario8Resource
      allow_unregistered? true
    end
  end

  # Scenario 7: Resource has page_size: 50, Domain has type: :numbered
  # Expected: type: :numbered (from domain), page_size: 50 (from resource)
  defmodule Scenario7Resource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.Resources.PaginationScenarios.ScenarioDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :scenario7
          route "/admin/scenario7"
        end

        columns do
          column :name
        end

        pagination page_size: 50
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

  # Scenario 8: Resource has type: :infinite, Domain has type: :numbered, page_size: 30
  # Expected: type: :infinite (from resource), page_size: 30 (from domain)
  defmodule Scenario8Resource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.Resources.PaginationScenarios.ScenarioDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :scenario8
          route "/admin/scenario8"
        end

        columns do
          column :name
        end

        pagination type: :infinite
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
end
