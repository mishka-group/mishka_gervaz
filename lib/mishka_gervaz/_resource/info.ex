defmodule MishkaGervaz.Resource.Info do
  @moduledoc """
  Introspection helpers for `MishkaGervaz.Resource`.

  This module provides access to resource-level configuration.

  ## Submodules

  - `MishkaGervaz.Resource.Info.Table` - Table configuration introspection

  ## Usage

      # Get full table config
      config = MishkaGervaz.Resource.Info.Table.config(MyResource)

      # Get columns
      columns = MishkaGervaz.Resource.Info.Table.columns(MyResource)

      # Get filters
      filters = MishkaGervaz.Resource.Info.Table.filters(MyResource)
  """

  defdelegate table_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :config
  defdelegate columns(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate column(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate filters(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate filter(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate row_actions(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate bulk_actions(resource), to: MishkaGervaz.Resource.Info.Table
end
