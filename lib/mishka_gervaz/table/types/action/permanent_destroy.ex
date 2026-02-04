defmodule MishkaGervaz.Table.Types.Action.PermanentDestroy do
  @moduledoc """
  Permanent destroy action type - renders a button to permanently delete archived records.

  ## Usage

      row_actions do
        action :permanent_destroy, type: :permanent_destroy
        action :delete_forever, type: :permanent_destroy, confirm: "This cannot be undone!"
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
      |> assign(:variant, :permanent_destroy)
      |> assign(
        :label,
        resolve_label(action[:ui][:label]) || dgettext("mishka_gervaz", "Delete Permanently")
      )
      |> assign(:record_id, record.id)
      |> assign(:target, target)
      |> assign(
        :confirm,
        action[:confirm] ||
          dgettext("mishka_gervaz", "Permanently delete this record? This cannot be undone.")
      )
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component
      phx-click="row_action"
      phx-value-event="permanent_destroy"
      phx-value-id={@record_id}
      phx-target={@target}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end
end
