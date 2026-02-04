defmodule MishkaGervaz.Table.Types.Action.Destroy do
  @moduledoc """
  Destroy action type - renders a delete button with confirmation.

  Used for delete actions that destroy a record.

  ## Usage

      row_actions do
        action :delete, type: :destroy
        action :remove, type: :destroy, confirm: "Delete this item permanently?"
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
      |> assign(:variant, :destroy)
      |> assign(:label, resolve_label(action[:ui][:label]) || dgettext("mishka_gervaz", "Delete"))
      |> assign(:record_id, record.id)
      |> assign(:target, target)
      |> assign(:confirm, action[:confirm] || dgettext("mishka_gervaz", "Are you sure?"))
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component
      phx-click="delete"
      phx-value-id={@record_id}
      phx-target={@target}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end
end
