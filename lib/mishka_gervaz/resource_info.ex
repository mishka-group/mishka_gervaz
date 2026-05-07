defmodule MishkaGervaz.ResourceInfo do
  @moduledoc """
  Delegate module for resource introspection.

  Provides a single entry point for reading both table and form configuration.
  For direct access (and for newer accessors not delegated here), use
  `MishkaGervaz.Resource.Info.Table` or `MishkaGervaz.Resource.Info.Form`.

  ## Naming convention

  - **Unprefixed** functions delegate to the Table info module (e.g. `columns/1`,
    `filters/1`, `pagination/1`, `hooks/1`, `stream_name/1`, `detected_preloads/1`,
    `all_preloads/2`, `pagination_enabled?/1`, …).
  - **`table_*`** functions are the same Table accessors exposed under an
    explicit prefix (e.g. `table_config/1`, `table_hooks/1`, `table_route/1`,
    `table_filter_groups/1`, `table_action_for/3`, …).
  - **`form_*`** functions delegate to the Form info module
    (e.g. `form_config/1`, `form_fields/1`, `form_groups/1`, `form_layout/1`,
    `form_steps/1`, `form_action_for/3`, `form_route/1`, …).

  Where the same name exists on both sides (e.g. `config`, `hooks`,
  `detected_preloads`, `all_preloads`, `stream_name`, `route`, `action_for`),
  use the explicit `table_*` / `form_*` form. The bare unprefixed form is
  Table-only.

  Note that the unprefixed Table action lookup is exposed as `get_action/3`
  (delegating to `Info.Table.action_for/3`) — the Form equivalent is
  `form_action_for/3`.

  ## Examples

      # Table side
      ResourceInfo.table_config(MyResource)
      ResourceInfo.columns(MyResource)
      ResourceInfo.filters(MyResource)
      ResourceInfo.pagination(MyResource)
      ResourceInfo.table_hooks(MyResource)

      # Form side
      ResourceInfo.form_config(MyResource)
      ResourceInfo.form_fields(MyResource)
      ResourceInfo.form_groups(MyResource)
      ResourceInfo.form_steps(MyResource)
      ResourceInfo.form_hooks(MyResource)

  ## Override-pillar accessors (not delegated here)

  The Phase A override-pillar introspection — `events/1`, `state/1`,
  `data_loader/1` — is available only on the underlying info modules:

      MishkaGervaz.Resource.Info.Table.events(MyResource)
      MishkaGervaz.Resource.Info.Table.state(MyResource)
      MishkaGervaz.Resource.Info.Table.data_loader(MyResource)

      MishkaGervaz.Resource.Info.Form.events(MyResource)
      MishkaGervaz.Resource.Info.Form.state(MyResource)
      MishkaGervaz.Resource.Info.Form.data_loader(MyResource)

  Other Form helpers also live only on `Info.Form`: `notices/1`, `notice/2`,
  `notices_at/2`, `header/1`, `footer/1`, `js_hook/2`, `preload_aliases/2`,
  `component_id/1`.
  """

  defdelegate table_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :config
  defdelegate columns(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate column(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate column_order(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate filters(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate filter(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate row_actions(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate row_action(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate bulk_actions(resource), to: MishkaGervaz.Resource.Info.Table

  defdelegate get_action(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :action_for

  defdelegate detected_preloads(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate all_preloads(resource, master?), to: MishkaGervaz.Resource.Info.Table
  defdelegate stream_name(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate hooks(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate refresh_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :refresh
  defdelegate url_sync_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :url_sync

  defdelegate pagination(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate pagination_enabled?(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate pagination_type(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate page_size(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate page_size_options(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate max_page_size(resource), to: MishkaGervaz.Resource.Info.Table

  defdelegate table_hooks(resource), to: MishkaGervaz.Resource.Info.Table, as: :hooks

  defdelegate table_detected_preloads(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :detected_preloads

  defdelegate table_all_preloads(resource, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :all_preloads

  defdelegate table_stream_name(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :stream_name

  defdelegate table_route(resource), to: MishkaGervaz.Resource.Info.Table, as: :route

  defdelegate table_filter_mode(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_mode

  defdelegate table_filter_groups(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_groups

  defdelegate table_filter_group(resource, name),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_group

  defdelegate table_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :action_for

  defdelegate form_config(resource), to: MishkaGervaz.Resource.Info.Form, as: :config
  defdelegate form_fields(resource), to: MishkaGervaz.Resource.Info.Form, as: :fields
  defdelegate form_field(resource, name), to: MishkaGervaz.Resource.Info.Form, as: :field
  defdelegate form_field_order(resource), to: MishkaGervaz.Resource.Info.Form, as: :field_order
  defdelegate form_groups(resource), to: MishkaGervaz.Resource.Info.Form, as: :groups
  defdelegate form_uploads(resource), to: MishkaGervaz.Resource.Info.Form, as: :uploads
  defdelegate form_submit(resource), to: MishkaGervaz.Resource.Info.Form, as: :submit
  defdelegate form_layout(resource), to: MishkaGervaz.Resource.Info.Form, as: :layout
  defdelegate form_steps(resource), to: MishkaGervaz.Resource.Info.Form, as: :steps
  defdelegate form_step(resource, name), to: MishkaGervaz.Resource.Info.Form, as: :step
  defdelegate form_navigation(resource), to: MishkaGervaz.Resource.Info.Form, as: :navigation
  defdelegate form_persistence(resource), to: MishkaGervaz.Resource.Info.Form, as: :persistence

  defdelegate form_step_groups(resource, step_name),
    to: MishkaGervaz.Resource.Info.Form,
    as: :step_groups

  defdelegate form_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Form,
    as: :action_for

  defdelegate form_hooks(resource), to: MishkaGervaz.Resource.Info.Form, as: :hooks

  defdelegate form_detected_preloads(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :detected_preloads

  defdelegate form_all_preloads(resource, master?),
    to: MishkaGervaz.Resource.Info.Form,
    as: :all_preloads

  defdelegate form_stream_name(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :stream_name

  defdelegate form_route(resource), to: MishkaGervaz.Resource.Info.Form, as: :route
end
