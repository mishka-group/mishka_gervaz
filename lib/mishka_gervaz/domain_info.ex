defmodule MishkaGervaz.DomainInfo do
  @moduledoc """
  Delegate module for domain introspection.

  For direct access, use `MishkaGervaz.Domain.Info.Table`.
  """

  defdelegate domain_config(domain), to: MishkaGervaz.Domain.Info.Table, as: :config
  defdelegate table(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate defaults(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate navigation(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate menu_groups(domain), to: MishkaGervaz.Domain.Info.Table
  defdelegate default_ui_adapter(domain), to: MishkaGervaz.Domain.Info.Table, as: :ui_adapter
  defdelegate default_pagination(domain), to: MishkaGervaz.Domain.Info.Table, as: :pagination
  defdelegate default_page_size(domain), to: MishkaGervaz.Domain.Info.Table, as: :page_size

  defdelegate default_page_size_options(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :page_size_options

  defdelegate default_max_page_size(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :max_page_size

  defdelegate default_realtime(domain), to: MishkaGervaz.Domain.Info.Table, as: :realtime
  defdelegate default_theme(domain), to: MishkaGervaz.Domain.Info.Table, as: :theme
  defdelegate default_refresh(domain), to: MishkaGervaz.Domain.Info.Table, as: :refresh
  defdelegate default_url_sync(domain), to: MishkaGervaz.Domain.Info.Table, as: :url_sync

  defdelegate form_defaults(domain), to: MishkaGervaz.Domain.Info.Form, as: :defaults
  defdelegate form_ui_adapter(domain), to: MishkaGervaz.Domain.Info.Form, as: :ui_adapter
  defdelegate form_actions(domain), to: MishkaGervaz.Domain.Info.Form, as: :actions
  defdelegate form_theme(domain), to: MishkaGervaz.Domain.Info.Form, as: :theme
  defdelegate form_layout(domain), to: MishkaGervaz.Domain.Info.Form, as: :layout
  defdelegate form_template(domain), to: MishkaGervaz.Domain.Info.Form, as: :template
  defdelegate form_features(domain), to: MishkaGervaz.Domain.Info.Form, as: :features
  defdelegate form_submit(domain), to: MishkaGervaz.Domain.Info.Form, as: :submit
end
