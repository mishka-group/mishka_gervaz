defmodule MishkaGervaz.Domain.Info do
  @moduledoc """
  Introspection helpers for `MishkaGervaz.Domain`.

  All functions use explicit `table_` or `form_` prefixes to avoid
  name collisions between DSL sections that share field names.

  ## Submodules

  - `MishkaGervaz.Domain.Info.Table` — Table defaults and navigation introspection
  - `MishkaGervaz.Domain.Info.Form`  — Form defaults introspection

  ## Naming convention

  Every delegate follows the same rule:

  - **`table_<fn>`** — delegates to `MishkaGervaz.Domain.Info.Table.<fn>`
    with the exact same name.
  - **`form_<fn>`**  — delegates to `MishkaGervaz.Domain.Info.Form.<fn>`
    with the exact same name.

  No unprefixed shortcuts, no renames, no suffixes. If you find an accessor
  on `Domain.Info.Table` named `x`, the delegate here is `table_x`. Same for
  Form. This mirrors the convention used by `MishkaGervaz.Resource.Info` and
  `MishkaGervaz.DomainInfo`.

  ## Examples

      # Whole domain config map (same data on both sides)
      Domain.Info.table_config(MyDomain)
      Domain.Info.form_config(MyDomain)

      # Inherited table defaults
      Domain.Info.table_defaults(MyDomain)
      Domain.Info.table_pagination(MyDomain)
      Domain.Info.table_realtime(MyDomain)

      # Domain-level navigation (lives on Domain.Info.Table)
      Domain.Info.table_navigation(MyDomain)
      Domain.Info.table_menu_groups(MyDomain)

      # Inherited form defaults
      Domain.Info.form_defaults(MyDomain)
      Domain.Info.form_actions(MyDomain)
      Domain.Info.form_layout(MyDomain)
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
