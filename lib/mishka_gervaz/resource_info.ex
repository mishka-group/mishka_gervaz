defmodule MishkaGervaz.ResourceInfo do
  @moduledoc """
  Delegate module for resource introspection.

  Provides a single entry point for reading both table and form configuration.
  For direct access (and for the few accessors not delegated here), use
  `MishkaGervaz.Resource.Info.Table` or `MishkaGervaz.Resource.Info.Form`.

  ## Naming convention

  Every delegate follows one of three patterns:

  - **`table_<fn>`** — delegates to `Info.Table.<fn>` with the same name
    (e.g. `table_config/1`, `table_hooks/1`, `table_route/1`, `table_state/1`,
    `table_events/1`, `table_data_loader/1`, `table_action_for/3`, …).
  - **`form_<fn>`** — delegates to `Info.Form.<fn>` with the same name
    (e.g. `form_config/1`, `form_fields/1`, `form_groups/1`, `form_state/1`,
    `form_events/1`, `form_data_loader/1`, `form_action_for/3`, …).
  - **Unprefixed** (legacy Table shortcuts) — `columns/1`, `filters/1`,
    `pagination/1`, `hooks/1`, `stream_name/1`, `detected_preloads/1`,
    `all_preloads/2`, `pagination_enabled?/1`, etc. New code should prefer
    `table_*` for clarity.

  Where the same name exists on both sides, always use the explicit
  `table_*` / `form_*` form.

  ## Legacy / non-canonical names

  Three older delegates do not follow the strict `<prefix>_<upstream_name>`
  convention. They are kept for backwards compatibility:

  - `get_action/3` — delegates to `Info.Table.action_for/3`. New code should use
    `table_action_for/3`.
  - `refresh_config/1` — delegates to `Info.Table.refresh/1`.
  - `url_sync_config/1` — delegates to `Info.Table.url_sync/1`.

  ## Examples

      # Table — top-level config, columns, filters, pagination, hooks
      ResourceInfo.table_config(MyResource)
      ResourceInfo.columns(MyResource)
      ResourceInfo.filters(MyResource)
      ResourceInfo.pagination(MyResource)
      ResourceInfo.table_hooks(MyResource)

      # Table — chrome / notices / archive
      ResourceInfo.table_header(MyResource)
      ResourceInfo.table_footer(MyResource)
      ResourceInfo.table_notices(MyResource)
      ResourceInfo.table_archive_enabled?(MyResource)

      # Table — overridable pillars (Phase A)
      ResourceInfo.table_state(MyResource)
      ResourceInfo.table_events(MyResource)
      ResourceInfo.table_data_loader(MyResource)

      # Form — top-level config, fields, groups, steps, hooks
      ResourceInfo.form_config(MyResource)
      ResourceInfo.form_fields(MyResource)
      ResourceInfo.form_groups(MyResource)
      ResourceInfo.form_steps(MyResource)
      ResourceInfo.form_hooks(MyResource)

      # Form — chrome / notices / component
      ResourceInfo.form_header(MyResource)
      ResourceInfo.form_notices(MyResource)
      ResourceInfo.form_component_id(MyResource)
      ResourceInfo.form_js_hook(MyResource, :on_save)

      # Form — overridable pillars (Phase A)
      ResourceInfo.form_state(MyResource)
      ResourceInfo.form_events(MyResource)
      ResourceInfo.form_data_loader(MyResource)

  ## Not delegated (internal-only)

  These accessors are intentionally not exposed through this module — they
  are framework-internal and only meaningful inside the dispatcher / hook
  runner / query builder. Call them on the info modules directly if you
  really need them:

  - `Info.Table.builtins/1` — internal hook-builtin map.
  - `Info.Table.get_hook/2` — internal sugar over `hooks/1`.
  - `Info.Table.preload_aliases/2` — used by the table query builder.
  - `Info.Form.preload_aliases/2` — used by the form data loader.
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

  # Phase A — overridable-pillar introspection
  defdelegate table_state(resource), to: MishkaGervaz.Resource.Info.Table, as: :state
  defdelegate table_events(resource), to: MishkaGervaz.Resource.Info.Table, as: :events

  defdelegate table_data_loader(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :data_loader

  # Layout / feature flags
  defdelegate table_layout(resource), to: MishkaGervaz.Resource.Info.Table, as: :layout
  defdelegate table_features(resource), to: MishkaGervaz.Resource.Info.Table, as: :features

  defdelegate table_feature_enabled?(resource, feature),
    to: MishkaGervaz.Resource.Info.Table,
    as: :feature_enabled?

  # Archive
  defdelegate table_archive_enabled?(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :archive_enabled?

  defdelegate table_archive_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :archive_action_for

  # Pagination UI
  defdelegate table_pagination_ui(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :pagination_ui

  # Chrome
  defdelegate table_header(resource), to: MishkaGervaz.Resource.Info.Table, as: :header
  defdelegate table_footer(resource), to: MishkaGervaz.Resource.Info.Table, as: :footer

  # Notices
  defdelegate table_notices(resource), to: MishkaGervaz.Resource.Info.Table, as: :notices

  defdelegate table_notice(resource, name),
    to: MishkaGervaz.Resource.Info.Table,
    as: :notice

  defdelegate table_notices_at(resource, position),
    to: MishkaGervaz.Resource.Info.Table,
    as: :notices_at

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

  # Phase A — overridable-pillar introspection
  defdelegate form_state(resource), to: MishkaGervaz.Resource.Info.Form, as: :state
  defdelegate form_events(resource), to: MishkaGervaz.Resource.Info.Form, as: :events

  defdelegate form_data_loader(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :data_loader

  # Component identity / JS hooks
  defdelegate form_component_id(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :component_id

  defdelegate form_js_hook(resource, name),
    to: MishkaGervaz.Resource.Info.Form,
    as: :js_hook

  # Chrome
  defdelegate form_header(resource), to: MishkaGervaz.Resource.Info.Form, as: :header
  defdelegate form_footer(resource), to: MishkaGervaz.Resource.Info.Form, as: :footer

  # Notices
  defdelegate form_notices(resource), to: MishkaGervaz.Resource.Info.Form, as: :notices

  defdelegate form_notice(resource, name),
    to: MishkaGervaz.Resource.Info.Form,
    as: :notice

  defdelegate form_notices_at(resource, position),
    to: MishkaGervaz.Resource.Info.Form,
    as: :notices_at
end
