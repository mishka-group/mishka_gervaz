defmodule MishkaGervaz.Resource.Info do
  @moduledoc """
  Introspection helpers for `MishkaGervaz.Resource`.

  All functions use explicit `table_` or `form_` prefixes to avoid
  name collisions between DSL types.

  ## Submodules

  - `MishkaGervaz.Resource.Info.Table` - Table configuration introspection
  - `MishkaGervaz.Resource.Info.Form` - Form configuration introspection

  ## Usage

      # Table introspection
      config  = MishkaGervaz.Resource.Info.table_config(MyResource)
      columns = MishkaGervaz.Resource.Info.table_columns(MyResource)
      hooks   = MishkaGervaz.Resource.Info.table_hooks(MyResource)

      # Form introspection
      config = MishkaGervaz.Resource.Info.form_config(MyResource)
      fields = MishkaGervaz.Resource.Info.form_fields(MyResource)
      hooks  = MishkaGervaz.Resource.Info.form_hooks(MyResource)
  """

  # ── Table delegates ──

  defdelegate table_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :config
  defdelegate table_columns(resource), to: MishkaGervaz.Resource.Info.Table, as: :columns
  defdelegate table_column(resource, name), to: MishkaGervaz.Resource.Info.Table, as: :column

  defdelegate table_column_order(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :column_order

  defdelegate table_filters(resource), to: MishkaGervaz.Resource.Info.Table, as: :filters
  defdelegate table_filter(resource, name), to: MishkaGervaz.Resource.Info.Table, as: :filter

  defdelegate table_row_actions(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :row_actions

  defdelegate table_row_action(resource, name),
    to: MishkaGervaz.Resource.Info.Table,
    as: :row_action

  defdelegate table_bulk_actions(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :bulk_actions

  defdelegate table_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :action_for

  defdelegate table_archive_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :archive_action_for

  defdelegate table_archive_enabled?(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :archive_enabled?

  defdelegate table_detected_preloads(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :detected_preloads

  defdelegate table_all_preloads(resource, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :all_preloads

  defdelegate table_preload_aliases(resource, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :preload_aliases

  defdelegate table_stream_name(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :stream_name

  defdelegate table_route(resource), to: MishkaGervaz.Resource.Info.Table, as: :route
  defdelegate table_hooks(resource), to: MishkaGervaz.Resource.Info.Table, as: :hooks
  defdelegate table_features(resource), to: MishkaGervaz.Resource.Info.Table, as: :features

  defdelegate table_feature_enabled?(resource, feature),
    to: MishkaGervaz.Resource.Info.Table,
    as: :feature_enabled?

  defdelegate table_refresh(resource), to: MishkaGervaz.Resource.Info.Table, as: :refresh
  defdelegate table_url_sync(resource), to: MishkaGervaz.Resource.Info.Table, as: :url_sync
  defdelegate table_state(resource), to: MishkaGervaz.Resource.Info.Table, as: :state

  defdelegate table_data_loader(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :data_loader

  defdelegate table_events(resource), to: MishkaGervaz.Resource.Info.Table, as: :events

  defdelegate table_filter_layout(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_layout

  defdelegate table_pagination_ui(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :pagination_ui

  # ── Form delegates ──

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
