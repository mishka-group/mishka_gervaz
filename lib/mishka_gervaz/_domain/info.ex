defmodule MishkaGervaz.Domain.Info do
  @moduledoc """
  Introspection helpers for `MishkaGervaz.Domain`.

  This module provides access to domain-level configuration.

  ## Submodules

  - `MishkaGervaz.Domain.Info.Table` - Table defaults and navigation introspection
  - `MishkaGervaz.Domain.Info.Form` - Form defaults introspection

  ## Usage

      # Get table defaults
      defaults = MishkaGervaz.Domain.Info.Table.defaults(MyDomain)

      # Get form defaults
      form_defaults = MishkaGervaz.Domain.Info.Form.defaults(MyDomain)

      # Get menu groups
      groups = MishkaGervaz.Domain.Info.Table.menu_groups(MyDomain)
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

  defdelegate form_defaults(domain), to: MishkaGervaz.Domain.Info.Form, as: :defaults
  defdelegate form_ui_adapter(domain), to: MishkaGervaz.Domain.Info.Form, as: :ui_adapter
  defdelegate form_actions(domain), to: MishkaGervaz.Domain.Info.Form, as: :actions
  defdelegate form_theme(domain), to: MishkaGervaz.Domain.Info.Form, as: :theme
  defdelegate form_layout(domain), to: MishkaGervaz.Domain.Info.Form, as: :layout
end
