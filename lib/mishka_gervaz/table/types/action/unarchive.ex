defmodule MishkaGervaz.Table.Types.Action.Unarchive do
  @moduledoc """
  Unarchive action type - renders a restore button for archived records.

  ## Usage

      row_actions do
        action :unarchive, type: :unarchive
        action :restore, type: :unarchive, confirm: "Restore this item?"
      end
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component
  use MishkaGervaz.Messages
  import MishkaGervaz.Helpers, only: [dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  def render(_assigns, action, record, ui, target) do
    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:variant, :unarchive)
      |> assign(
        :label,
        resolve_label(action[:ui][:label]) || dgettext("mishka_gervaz", "Restore")
      )
      |> assign(:record_id, record.id)
      |> assign(:target, target)
      |> assign(:confirm, action[:confirm] || dgettext("mishka_gervaz", "Restore this record?"))
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component
      phx-click="row_action"
      phx-value-event="unarchive"
      phx-value-id={@record_id}
      phx-target={@target}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end
end
