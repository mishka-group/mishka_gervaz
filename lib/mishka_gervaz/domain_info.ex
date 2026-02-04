defmodule MishkaGervaz.DomainInfo do
  @moduledoc """
  Delegate module for domain introspection.

  For direct access, use `MishkaGervaz.Domain.Info.Table`.
  """

  # Delegate all functions to the new module structure
  defdelegate domain_config(domain), to: MishkaGervaz.Domain.Info.Table, as: :config
  defdelegate table(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate defaults(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate navigation(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate menu_groups(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate default_ui_adapter(domain), to: MishkaGervaz.Domain.Info.Table, as: :ui_adapter
  defdelegate default_pagination(domain), to: MishkaGervaz.Domain.Info.Table, as: :pagination
  defdelegate default_realtime(domain), to: MishkaGervaz.Domain.Info.Table, as: :realtime
  defdelegate default_theme(domain), to: MishkaGervaz.Domain.Info.Table, as: :theme
  defdelegate default_refresh(domain), to: MishkaGervaz.Domain.Info.Table, as: :refresh
  defdelegate default_url_sync(domain), to: MishkaGervaz.Domain.Info.Table, as: :url_sync
end
