defmodule MishkaGervaz.Table.Types.Action.Drawer do
  @moduledoc """
  Drawer action type - renders a button that opens the row in the table's drawer.

  The drawer shows the row's record view or the resource's own form editing the row, under a head
  built from the row: an icon tile, a title, a line under it, chips and buttons. The table reads
  the row again by its id as the drawer opens, under the table's own read action and tenant, so a
  row that is gone opens nothing.

  ## Usage

      row_actions do
        action :view, type: :drawer,
          open: fn record -> MyAppWeb.OrderViews.order(%{order: record}) end,
          drawer: [
            title: fn record -> record.number end,
            sub: fn record -> record.customer_name end,
            icon: "hero-receipt-percent",
            tone: :info,
            chips: fn record -> [{:ok, "Paid"}, record.provider] end,
            actions: fn record -> MyAppWeb.OrderViews.order_actions(%{order: record}) end
          ]

        action :edit, type: :drawer, open: :form, drawer: [kind: :sheet, title: "Edit order"]
      end

  `open: :form` mounts `MishkaGervaz.Form.Web.Live` for the table's resource, with the id
  `"<table id>-drawer-form"` and the row's id as its `record_id`. The form tells the page
  `{:form_saved, mode, record}` as any form does; the page closes the drawer and puts the saved row
  back in its place with `MishkaGervaz.Table.Web.Live.close_drawer/2`.

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Behaviours.ActionType`,
  `MishkaGervaz.Table.Entities.RowAction`, and
  `MishkaGervaz.Table.Templates.Shared.render_row_drawer/1`.

  `MishkaGervaz.Table.Behaviours.ActionType` documents what may go in the assigns map.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [action_label: 1, dynamic_component: 1, maybe_assign: 3]

  @impl true
  def render(_assigns, action, record, ui, target) do
    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:variant, :default)
      |> assign(:label, action_label(action))
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])
      |> assign(:phx_click, "open_drawer")
      |> assign(:phx_value_action, to_string(action[:name]))
      |> assign(:phx_value_id, record.id)
      |> assign(:phx_target, target)

    ~H"""
    <.dynamic_component {assigns} />
    """
  end
end
