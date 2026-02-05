defmodule MishkaGervaz.Resource.Info do
  @moduledoc """
  Introspection helpers for `MishkaGervaz.Resource`.

  This module provides access to resource-level configuration.

  ## Submodules

  - `MishkaGervaz.Resource.Info.Table` - Table configuration introspection
  - `MishkaGervaz.Resource.Info.Form` - Form configuration introspection

  ## Usage

      # Get full table config
      config = MishkaGervaz.Resource.Info.Table.config(MyResource)

      # Get columns
      columns = MishkaGervaz.Resource.Info.Table.columns(MyResource)

      # Get full form config
      config = MishkaGervaz.Resource.Info.Form.config(MyResource)

      # Get fields
      fields = MishkaGervaz.Resource.Info.Form.fields(MyResource)
  """

  # Table delegates
  defdelegate table_config(resource), to: MishkaGervaz.Resource.Info.Table, as: :config
  defdelegate columns(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate column(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate filters(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate filter(resource, name), to: MishkaGervaz.Resource.Info.Table
  defdelegate row_actions(resource), to: MishkaGervaz.Resource.Info.Table
  defdelegate bulk_actions(resource), to: MishkaGervaz.Resource.Info.Table

  # Form delegates
  defdelegate form_config(resource), to: MishkaGervaz.Resource.Info.Form, as: :config
  defdelegate fields(resource), to: MishkaGervaz.Resource.Info.Form
  defdelegate field(resource, name), to: MishkaGervaz.Resource.Info.Form
  defdelegate groups(resource), to: MishkaGervaz.Resource.Info.Form
  defdelegate uploads(resource), to: MishkaGervaz.Resource.Info.Form
  defdelegate submit(resource), to: MishkaGervaz.Resource.Info.Form
  defdelegate form_layout(resource), to: MishkaGervaz.Resource.Info.Form, as: :layout
  defdelegate form_hooks(resource), to: MishkaGervaz.Resource.Info.Form, as: :hooks
end
