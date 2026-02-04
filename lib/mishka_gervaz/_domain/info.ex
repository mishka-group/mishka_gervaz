defmodule MishkaGervaz.Domain.Info do
  @moduledoc """
  Introspection helpers for `MishkaGervaz.Domain`.

  This module provides access to domain-level configuration.

  ## Submodules

  - `MishkaGervaz.Domain.Info.Table` - Table defaults and navigation introspection

  ## Usage

      # Get table defaults
      defaults = MishkaGervaz.Domain.Info.Table.defaults(MyDomain)

      # Get menu groups
      groups = MishkaGervaz.Domain.Info.Table.menu_groups(MyDomain)

      # Get default pagination
      pagination = MishkaGervaz.Domain.Info.Table.pagination(MyDomain)
  """

  defdelegate config(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate defaults(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate navigation(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate menu_groups(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate pagination(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate realtime(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate theme(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate refresh(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate url_sync(domain), to: MishkaGervaz.Domain.Info.Table
end
