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
      is_expanded = assigns[:state] && assigns[:state].expanded_id == to_string(record.id)

      assigns =
        %{__changed__: %{}}
        |> assign(:module, ui)
        |> assign(:function, :button)
        |> assign(:variant, :default)
        |> assign(
          :label,
          resolve_label(action[:ui][:label]) || dgettext("mishka_gervaz", "Expand")
        )
        |> assign(:record_id, record.id)
        |> assign(:target, target)
        |> assign(:is_expanded, is_expanded)
        |> maybe_assign(:icon, action[:ui][:icon])
        |> maybe_assign(:class, action[:ui][:class])

      ~H"""
      <.dynamic_component
        phx-click="expand_row"
        phx-value-id={@record_id}
        phx-target={@target}
        {assigns}
      />
      """
    end
  end
end
