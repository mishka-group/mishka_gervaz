defmodule MishkaGervaz.Table.Types.Action.Update do
  @moduledoc """
  Update action type - renders a button that triggers an Ash update action.

  ## Usage

      row_actions do
        action :activate, type: :update, action: :activate
        action :set_master, type: :update, action: {:master_set_master, :set_master}
      end

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Behaviours.ActionType`,
  `MishkaGervaz.Table.Entities.RowAction`, and
  `MishkaGervaz.Table.Entities.BulkAction`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [
      humanize: 1,
      dynamic_component: 1,
      maybe_assign: 3,
      resolve_label: 1,
      resolve_confirm: 2
    ]

  @impl true
  def render(_assigns, action, record, ui, target) do
    event = action[:event] || to_string(action[:name])

    # ONLY WHAT THE COMPONENT DECLARES, PLUS REAL ATTRIBUTES. The map below is splatted straight at the
    # UI adapter, whose `button/1` declares `attr :rest, :global` — so every key it does not recognise
    # was written into the DOM as an attribute of its own (`record_id`, `target`, `confirm`), on every
    # row of every table. The bindings now travel under their own names; `MishkaGervaz.Helpers`
    # dashes the `phx_`/`data_` keys on the way through `dynamic_component/1`.
    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:variant, :default)
      |> assign(:label, resolve_label(action[:ui][:label]) || humanize(action[:name]))
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])
      |> assign(:phx_click, "row_action")
      |> assign(:phx_value_event, event)
      |> assign(:phx_value_id, record.id)
      |> assign(:phx_target, target)
      |> assign(:data_confirm, resolve_confirm(action[:confirm], record))

    ~H"""
    <.dynamic_component {assigns} />
    """
  end
end
