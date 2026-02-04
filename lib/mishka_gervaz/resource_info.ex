defmodule MishkaGervaz.ResourceInfo do
  @moduledoc """
  Delegate module for resource introspection.

  For direct access, use `MishkaGervaz.Resource.Info.Table`.
  """

  # Delegate all functions to the new module structure
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
end
