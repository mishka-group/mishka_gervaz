defmodule MishkaGervaz.ResourceInfo do
  @moduledoc """
  Delegate module for resource introspection.

  Provides prefixed access to both table and form info modules.
  For direct access, use `MishkaGervaz.Resource.Info.Table` or
  `MishkaGervaz.Resource.Info.Form`.

  ## Table Functions

      ResourceInfo.table_config(resource)
      ResourceInfo.columns(resource)
      ResourceInfo.table_hooks(resource)

  ## Form Functions

      ResourceInfo.form_config(resource)
      ResourceInfo.form_fields(resource)
      ResourceInfo.form_hooks(resource)

  Overlapping functions (config, hooks, detected_preloads, all_preloads,
  stream_name, route, action_for) are available with explicit `table_` or
  `form_` prefixes. The unprefixed versions delegate to Table.
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
