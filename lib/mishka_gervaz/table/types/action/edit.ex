defmodule MishkaGervaz.Table.Types.Action.Edit do
  @moduledoc """
  Edit action type - renders a button that sends the record to the form component.

  Dispatches a `row_action` event with the action name and record ID, which is
  intercepted by the table events handler to send directly to the form component
  via `send_update`.

  ## Usage

      row_actions do
        action :edit, type: :edit
        action :edit, type: :edit, js: fn _record -> JS.exec("data-show-modal", to: "#form-modal") end
      end

  ## JS Hook

  When `js` is set, the user's JS commands run first, then the push event is chained:

      action :edit, type: :edit, js: fn _record ->
        JS.exec("data-show-modal", to: "#form-modal")
      end
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  import MishkaGervaz.Helpers,
    only: [humanize: 1, dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  def render(_assigns, action, record, ui, target) do
    event_name = to_string(action[:name])
    push_value = %{event: event_name, id: record.id}

    click_js =
      case action[:js] do
        func when is_function(func, 1) ->
          record |> func.() |> JS.push("row_action", value: push_value, target: target)

        _ ->
          JS.push("row_action", value: push_value, target: target)
      end

    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:variant, :default)
      |> assign(:label, resolve_label(action[:ui][:label]) || humanize(action[:name]))
      |> assign(:click_js, click_js)
      |> assign(:confirm, action[:confirm])
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component
      phx-click={@click_js}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end
end
