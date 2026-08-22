defmodule MishkaGervaz.Table.Types.Action.Destroy do
  @moduledoc """
  Destroy action type - renders a delete button with confirmation.

  Used for delete actions that destroy a record.

  ## Usage

      row_actions do
        action :delete, type: :destroy
        action :remove, type: :destroy, confirm: "Delete this item permanently?"
      end

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Behaviours.ActionType`,
  `MishkaGervaz.Table.Entities.RowAction`, and
  `MishkaGervaz.Table.Entities.BulkAction`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers,
    only: [dynamic_component: 1, maybe_assign: 3, resolve_label: 1, resolve_confirm: 2]

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
      |> assign(:variant, :destroy)
      |> assign(:label, resolve_label(action[:ui][:label]) || dgettext("mishka_gervaz", "Delete"))
      |> assign(:icon, action[:ui][:icon] || "hero-trash")
      |> maybe_assign(:class, action[:ui][:class])
      |> assign(:phx_click, "delete")
      |> assign(:phx_value_id, record.id)
      |> assign(:phx_target, target)
      |> assign(
        :data_confirm,
        resolve_confirm(action[:confirm], record) || dgettext("mishka_gervaz", "Are you sure?")
      )

    ~H"""
    <.dynamic_component {assigns} />
    """
  end
end
