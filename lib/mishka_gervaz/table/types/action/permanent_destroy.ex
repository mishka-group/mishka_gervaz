defmodule MishkaGervaz.Table.Types.Action.PermanentDestroy do
  @moduledoc """
  Permanent destroy action type - renders a button to permanently delete archived records.

  ## Usage

      row_actions do
        action :permanent_destroy, type: :permanent_destroy
        action :delete_forever, type: :permanent_destroy, confirm: "This cannot be undone!"
      end

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Behaviours.ActionType`,
  `MishkaGervaz.Table.Entities.RowAction`, and
  `MishkaGervaz.Table.Entities.BulkAction`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component
  use MishkaGervaz.Messages
  import MishkaGervaz.Helpers, only: [dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  # ONLY WHAT THE COMPONENT DECLARES, PLUS REAL ATTRIBUTES. The map below is splatted straight at the
  # UI adapter, whose `button/1` declares `attr :rest, :global` — so every key it does not recognise
  # was written into the DOM as an attribute of its own (`record_id`, `target`, `confirm`), on every
  # row of every table. The bindings now travel under their own names; `MishkaGervaz.Helpers`
  # dashes the `phx_`/`data_` keys on the way through `dynamic_component/1`.
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
      |> assign(:icon, action[:ui][:icon] || "hero-x-circle")
      |> maybe_assign(:class, action[:ui][:class])
      |> assign(:phx_click, "row_action")
      |> assign(:phx_value_event, "permanent_destroy")
      |> assign(:phx_value_id, record.id)
      |> assign(:phx_target, target)
      |> assign(
        :data_confirm,
        action[:confirm] ||
          dgettext("mishka_gervaz", "Permanently delete this record? This cannot be undone.")
      )

    ~H"""
    <.dynamic_component {assigns} />
    """
  end
end
