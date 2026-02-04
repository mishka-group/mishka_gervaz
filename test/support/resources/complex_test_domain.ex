defmodule MishkaGervaz.Test.Resources.ComplexTestDomain do
  @moduledoc """
  Complex test domain for comprehensive DSL testing.
  """
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_admin
      master_check fn user -> user.role == :admin end
      pagination page_size: 25, type: :numbered
      ui_adapter MishkaGervaz.Table.UIAdapters.Tailwind
    end
  end

  resources do
    allow_unregistered? true
  end
end
