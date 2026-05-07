defmodule MishkaGervaz.ResourceInfo do
  @moduledoc """
  Delegate module for resource introspection.

  Provides a single entry point for reading both table and form configuration.
  For direct access use `MishkaGervaz.Resource.Info.Table` or
  `MishkaGervaz.Resource.Info.Form`.

  ## Naming convention

  Every delegate follows the same rule:

  - **`table_<fn>`** — delegates to `MishkaGervaz.Resource.Info.Table.<fn>` with
    the exact same name.
  - **`form_<fn>`**  — delegates to `MishkaGervaz.Resource.Info.Form.<fn>` with
    the exact same name.

  No unprefixed shortcuts, no renames, no suffixes. If you find an accessor
  on `Info.Table` named `x`, the delegate here is `table_x`. Same for Form.

  ## Examples

      # Table — top-level / structural
      ResourceInfo.table_config(MyResource)
      ResourceInfo.table_columns(MyResource)
      ResourceInfo.table_filters(MyResource)
      ResourceInfo.table_pagination(MyResource)
      ResourceInfo.table_hooks(MyResource)
      ResourceInfo.table_route(MyResource)

      # Table — chrome / notices / archive / features
      ResourceInfo.table_header(MyResource)
      ResourceInfo.table_footer(MyResource)
      ResourceInfo.table_notices(MyResource)
      ResourceInfo.table_archive_enabled?(MyResource)
      ResourceInfo.table_features(MyResource)

      # Table — overridable pillars
      ResourceInfo.table_state(MyResource)
      ResourceInfo.table_events(MyResource)
      ResourceInfo.table_data_loader(MyResource)

      # Form — top-level / structural
      ResourceInfo.form_config(MyResource)
      ResourceInfo.form_fields(MyResource)
      ResourceInfo.form_groups(MyResource)
      ResourceInfo.form_steps(MyResource)
      ResourceInfo.form_hooks(MyResource)
      ResourceInfo.form_route(MyResource)

      # Form — chrome / notices / component / JS hooks
      ResourceInfo.form_header(MyResource)
      ResourceInfo.form_notices(MyResource)
      ResourceInfo.form_component_id(MyResource)
      ResourceInfo.form_js_hook(MyResource, :on_save)

      # Form — overridable pillars
      ResourceInfo.form_state(MyResource)
      ResourceInfo.form_events(MyResource)
      ResourceInfo.form_data_loader(MyResource)

  ## Not delegated (internal-only)

  These accessors are intentionally not exposed here — they are
  framework-internal and only meaningful inside the dispatcher / hook
  runner / query builder. Call them on the info modules directly if needed:

  - `MishkaGervaz.Resource.Info.Table.builtins/1` — internal hook-builtin map
  - `MishkaGervaz.Resource.Info.Table.get_hook/2` — internal sugar over `hooks/1`
  - `MishkaGervaz.Resource.Info.Table.preload_aliases/2` — used by the query builder
  - `MishkaGervaz.Resource.Info.Form.preload_aliases/2`  — used by the form data loader
  """

  defdelegate table_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :config
  defdelegate table_route(resource), to: MishkaGervaz.Resource.Info.Table, as: :route
  defdelegate table_stream_name(resource), to: MishkaGervaz.Resource.Info.Table, as: :stream_name
  defdelegate table_layout(resource), to: MishkaGervaz.Resource.Info.Table, as: :layout
  defdelegate table_features(resource), to: MishkaGervaz.Resource.Info.Table, as: :features

  defdelegate table_feature_enabled?(resource, feature),
    to: MishkaGervaz.Resource.Info.Table,
    as: :feature_enabled?

  defdelegate table_hooks(resource), to: MishkaGervaz.Resource.Info.Table, as: :hooks

  defdelegate table_detected_preloads(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :detected_preloads

  defdelegate table_all_preloads(resource, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :all_preloads

  defdelegate table_columns(resource), to: MishkaGervaz.Resource.Info.Table, as: :columns
  defdelegate table_column(resource, name), to: MishkaGervaz.Resource.Info.Table, as: :column

  defdelegate table_column_order(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :column_order

  defdelegate table_filters(resource), to: MishkaGervaz.Resource.Info.Table, as: :filters
  defdelegate table_filter(resource, name), to: MishkaGervaz.Resource.Info.Table, as: :filter

  defdelegate table_filter_mode(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_mode

  defdelegate table_filter_groups(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_groups

  defdelegate table_filter_group(resource, name),
    to: MishkaGervaz.Resource.Info.Table,
    as: :filter_group

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

  defdelegate table_archive_enabled?(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :archive_enabled?

  defdelegate table_archive_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Table,
    as: :archive_action_for

  defdelegate table_pagination(resource), to: MishkaGervaz.Resource.Info.Table, as: :pagination

  defdelegate table_pagination_enabled?(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :pagination_enabled?

  defdelegate table_pagination_type(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :pagination_type

  defdelegate table_pagination_ui(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :pagination_ui

  defdelegate table_page_size(resource), to: MishkaGervaz.Resource.Info.Table, as: :page_size

  defdelegate table_page_size_options(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :page_size_options

  defdelegate table_max_page_size(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :max_page_size

  defdelegate table_refresh(resource), to: MishkaGervaz.Resource.Info.Table, as: :refresh
  defdelegate table_url_sync(resource), to: MishkaGervaz.Resource.Info.Table, as: :url_sync

  defdelegate table_header(resource), to: MishkaGervaz.Resource.Info.Table, as: :header
  defdelegate table_footer(resource), to: MishkaGervaz.Resource.Info.Table, as: :footer
  defdelegate table_notices(resource), to: MishkaGervaz.Resource.Info.Table, as: :notices
  defdelegate table_notice(resource, name), to: MishkaGervaz.Resource.Info.Table, as: :notice

  defdelegate table_notices_at(resource, position),
    to: MishkaGervaz.Resource.Info.Table,
    as: :notices_at

  defdelegate table_state(resource), to: MishkaGervaz.Resource.Info.Table, as: :state
  defdelegate table_events(resource), to: MishkaGervaz.Resource.Info.Table, as: :events

  defdelegate table_data_loader(resource),
    to: MishkaGervaz.Resource.Info.Table,
    as: :data_loader

  defdelegate form_config(resource), to: MishkaGervaz.Resource.Info.Form, as: :config
  defdelegate form_route(resource), to: MishkaGervaz.Resource.Info.Form, as: :route
  defdelegate form_stream_name(resource), to: MishkaGervaz.Resource.Info.Form, as: :stream_name
  defdelegate form_layout(resource), to: MishkaGervaz.Resource.Info.Form, as: :layout
  defdelegate form_navigation(resource), to: MishkaGervaz.Resource.Info.Form, as: :navigation
  defdelegate form_persistence(resource), to: MishkaGervaz.Resource.Info.Form, as: :persistence

  defdelegate form_component_id(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :component_id

  defdelegate form_hooks(resource), to: MishkaGervaz.Resource.Info.Form, as: :hooks

  defdelegate form_detected_preloads(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :detected_preloads

  defdelegate form_all_preloads(resource, master?),
    to: MishkaGervaz.Resource.Info.Form,
    as: :all_preloads

  defdelegate form_js_hook(resource, name),
    to: MishkaGervaz.Resource.Info.Form,
    as: :js_hook

  defdelegate form_fields(resource), to: MishkaGervaz.Resource.Info.Form, as: :fields
  defdelegate form_field(resource, name), to: MishkaGervaz.Resource.Info.Form, as: :field

  defdelegate form_field_order(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :field_order

  defdelegate form_groups(resource), to: MishkaGervaz.Resource.Info.Form, as: :groups
  defdelegate form_steps(resource), to: MishkaGervaz.Resource.Info.Form, as: :steps
  defdelegate form_step(resource, name), to: MishkaGervaz.Resource.Info.Form, as: :step

  defdelegate form_step_groups(resource, step_name),
    to: MishkaGervaz.Resource.Info.Form,
    as: :step_groups

  defdelegate form_uploads(resource), to: MishkaGervaz.Resource.Info.Form, as: :uploads
  defdelegate form_submit(resource), to: MishkaGervaz.Resource.Info.Form, as: :submit

  defdelegate form_action_for(resource, type, master?),
    to: MishkaGervaz.Resource.Info.Form,
    as: :action_for

  defdelegate form_header(resource), to: MishkaGervaz.Resource.Info.Form, as: :header
  defdelegate form_footer(resource), to: MishkaGervaz.Resource.Info.Form, as: :footer
  defdelegate form_notices(resource), to: MishkaGervaz.Resource.Info.Form, as: :notices
  defdelegate form_notice(resource, name), to: MishkaGervaz.Resource.Info.Form, as: :notice

  defdelegate form_notices_at(resource, position),
    to: MishkaGervaz.Resource.Info.Form,
    as: :notices_at

  defdelegate form_state(resource), to: MishkaGervaz.Resource.Info.Form, as: :state
  defdelegate form_events(resource), to: MishkaGervaz.Resource.Info.Form, as: :events

  defdelegate form_data_loader(resource),
    to: MishkaGervaz.Resource.Info.Form,
    as: :data_loader
end
