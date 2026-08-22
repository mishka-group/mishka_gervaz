defmodule MishkaGervaz.Table.Types.Action.Accordion do
  @moduledoc """
  Accordion action type - renders an expand/collapse button for row details.

  Fires the `"expand_row"` event directly on the table component, which triggers
  the internal expand state management (setting `expanded_id`, `expanded_data`)
  and sends `{:expand_row, id}` to the parent LiveView for async content loading.

  ## Usage

      row_actions do
        action :expand, type: :accordion
      end

  The parent LiveView handles `{:expand_row, id}` to load data, then sends
  the rendered HTML back via:

      send_update(MishkaGervaz.Table.Web.Live,
        id: "my-table",
        expanded_html: html
      )

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Behaviours.ActionType`,
  `MishkaGervaz.Table.Entities.RowAction`, and
  `MishkaGervaz.Table.Entities.BulkAction`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers,
    only: [dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  def render(assigns, action, record, ui, target) do
    features = (assigns[:static] && assigns[:static].features) || []

    if :expand not in features do
      assigns = %{__changed__: %{}}

      ~H""
    else
      # Whether the row is open is NOT read here. `MishkaGervaz.Table.Templates.Table` works it out
      # again for the caret it draws and for the detail row itself; this button only asks for the
      # toggle. It used to be computed and handed to `button/1`, which has no use for it either and
      # published it as an `is_expanded` attribute.
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
        |> assign(
          :label,
          resolve_label(action[:ui][:label]) || dgettext("mishka_gervaz", "Expand")
        )
        |> maybe_assign(:icon, action[:ui][:icon])
        |> maybe_assign(:class, action[:ui][:class])
        |> assign(:phx_click, "expand_row")
        |> assign(:phx_value_id, record.id)
        |> assign(:phx_target, target)

      ~H"""
      <.dynamic_component {assigns} />
      """
    end
  end
end
