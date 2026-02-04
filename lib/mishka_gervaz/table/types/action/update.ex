defmodule MishkaGervaz.Table.Types.Action.Update do
  @moduledoc """
  Update action type - renders a button that triggers an Ash update action.

  ## Usage

      row_actions do
        action :activate, type: :update, action: :activate
        action :set_master, type: :update, action: {:master_set_master, :set_master}
      end
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [humanize: 1, dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  def render(_assigns, action, record, ui, target) do
    event = action[:event] || to_string(action[:name])

    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:variant, :default)
      |> assign(:label, resolve_label(action[:ui][:label]) || humanize(action[:name]))
      |> assign(:record_id, record.id)
      |> assign(:event, event)
      |> assign(:target, target)
      |> assign(:confirm, action[:confirm])
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component
      phx-click="row_action"
      phx-value-event={@event}
      phx-value-id={@record_id}
      phx-target={@target}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end
end
