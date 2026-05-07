defmodule MishkaGervaz.DomainInfo do
  @moduledoc """
  Delegate module for domain introspection.

  Provides a single entry point for reading domain-level table and form
  defaults. For direct access use `MishkaGervaz.Domain.Info.Table` or
  `MishkaGervaz.Domain.Info.Form`.

  ## Naming convention

  Every delegate follows the same rule:

  - **`table_<fn>`** — delegates to `MishkaGervaz.Domain.Info.Table.<fn>`
    with the exact same name.
  - **`form_<fn>`**  — delegates to `MishkaGervaz.Domain.Info.Form.<fn>`
    with the exact same name.

  No unprefixed shortcuts, no renames, no suffixes. If you find an accessor
  on `Domain.Info.Table` named `x`, the delegate here is `table_x`. Same
  for Form.

  ## Examples

      # Whole domain config map (same data on both sides)
      DomainInfo.table_config(MyDomain)
      DomainInfo.form_config(MyDomain)

      # Inherited table defaults
      DomainInfo.table_defaults(MyDomain)
      DomainInfo.table_actor_key(MyDomain)
      DomainInfo.table_master_check(MyDomain)
      DomainInfo.table_pagination(MyDomain)
      DomainInfo.table_page_size(MyDomain)
      DomainInfo.table_realtime(MyDomain)
      DomainInfo.table_theme(MyDomain)
      DomainInfo.table_refresh(MyDomain)
      DomainInfo.table_url_sync(MyDomain)
      DomainInfo.table_actions(MyDomain)

      # Domain-level navigation (lives on Domain.Info.Table)
      DomainInfo.table_navigation(MyDomain)
      DomainInfo.table_menu_groups(MyDomain)

      # Inherited form defaults
      DomainInfo.form_defaults(MyDomain)
      DomainInfo.form_actor_key(MyDomain)
      DomainInfo.form_master_check(MyDomain)
      DomainInfo.form_actions(MyDomain)
      DomainInfo.form_theme(MyDomain)
      DomainInfo.form_layout(MyDomain)
      DomainInfo.form_template(MyDomain)
      DomainInfo.form_features(MyDomain)
      DomainInfo.form_submit(MyDomain)
  """

  defdelegate table_config(domain), to: MishkaGervaz.Domain.Info.Table, as: :config
  defdelegate table_defaults(domain), to: MishkaGervaz.Domain.Info.Table, as: :defaults
  defdelegate table_navigation(domain), to: MishkaGervaz.Domain.Info.Table, as: :navigation

  defdelegate table_menu_groups(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :menu_groups

  defdelegate table_ui_adapter(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :ui_adapter

  defdelegate table_ui_adapter_opts(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :ui_adapter_opts

  defdelegate table_actor_key(domain), to: MishkaGervaz.Domain.Info.Table, as: :actor_key

  defdelegate table_master_check(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :master_check

  defdelegate table_actions(domain), to: MishkaGervaz.Domain.Info.Table, as: :actions
  defdelegate table_pagination(domain), to: MishkaGervaz.Domain.Info.Table, as: :pagination
  defdelegate table_page_size(domain), to: MishkaGervaz.Domain.Info.Table, as: :page_size

  defdelegate table_page_size_options(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :page_size_options

  defdelegate table_max_page_size(domain),
    to: MishkaGervaz.Domain.Info.Table,
    as: :max_page_size

  defdelegate table_realtime(domain), to: MishkaGervaz.Domain.Info.Table, as: :realtime
  defdelegate table_theme(domain), to: MishkaGervaz.Domain.Info.Table, as: :theme
  defdelegate table_refresh(domain), to: MishkaGervaz.Domain.Info.Table, as: :refresh
  defdelegate table_url_sync(domain), to: MishkaGervaz.Domain.Info.Table, as: :url_sync

  defdelegate form_config(domain), to: MishkaGervaz.Domain.Info.Form, as: :config
  defdelegate form_defaults(domain), to: MishkaGervaz.Domain.Info.Form, as: :defaults

  defdelegate form_ui_adapter(domain),
    to: MishkaGervaz.Domain.Info.Form,
    as: :ui_adapter

  defdelegate form_ui_adapter_opts(domain),
    to: MishkaGervaz.Domain.Info.Form,
    as: :ui_adapter_opts

  defdelegate form_actor_key(domain), to: MishkaGervaz.Domain.Info.Form, as: :actor_key

  defdelegate form_master_check(domain),
    to: MishkaGervaz.Domain.Info.Form,
    as: :master_check

  defdelegate form_actions(domain), to: MishkaGervaz.Domain.Info.Form, as: :actions
  defdelegate form_theme(domain), to: MishkaGervaz.Domain.Info.Form, as: :theme
  defdelegate form_layout(domain), to: MishkaGervaz.Domain.Info.Form, as: :layout
  defdelegate form_template(domain), to: MishkaGervaz.Domain.Info.Form, as: :template
  defdelegate form_features(domain), to: MishkaGervaz.Domain.Info.Form, as: :features
  defdelegate form_submit(domain), to: MishkaGervaz.Domain.Info.Form, as: :submit
end
