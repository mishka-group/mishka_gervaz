defmodule MishkaGervaz.Table.Types.Action.Event do
  @moduledoc """
  Event action type - renders a button that triggers a LiveView event.

  Used for custom actions that need to send events to the component/parent.

  ## Usage

      row_actions do
        action :approve, type: :event, event: "approve_record"
        action :archive, type: :event, confirm: "Are you sure?"
      end

  ## Payload

  By default, sends `%{id: record.id}`. Use `:payload` for custom data:

      action :process, type: :event, payload: fn record ->
        %{id: record.id, status: record.status}
      end
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [humanize: 1, dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  def render(_assigns, action, record, ui, target) do
    event = action[:event] || to_string(action[:name])

    values =
      case action[:payload] do
        func when is_function(func, 1) -> Jason.encode!(func.(record))
        _ -> Jason.encode!(%{id: record.id})
      end

    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:variant, action_variant(action[:name]))
      |> assign(:label, resolve_label(action[:ui][:label]) || humanize(action[:name]))
      |> assign(:event, event)
      |> assign(:values, values)
      |> assign(:target, target)
      |> assign(:confirm, action[:confirm])
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component
      phx-click="custom_event"
      phx-value-event={@event}
      phx-value-values={@values}
      phx-target={@target}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end

  @spec action_variant(atom()) :: atom()
  defp action_variant(:delete), do: :destroy
  defp action_variant(_), do: :default
end
