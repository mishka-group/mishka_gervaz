defmodule MishkaGervaz.Test.Resources.ActionResolutionDomain do
  @moduledoc """
  Test domain with explicit action defaults for testing action resolution.
  """
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end

      actions do
        read {:domain_master_read, :domain_tenant_read}
        get {:domain_master_get, :domain_get}
        destroy {:domain_master_destroy, :domain_destroy}
      end
    end
  end

  resources do
    resource MishkaGervaz.Test.Resources.DomainDefaultsResource
    resource MishkaGervaz.Test.Resources.MultiTenantResource
    allow_unregistered? true
  end
end
