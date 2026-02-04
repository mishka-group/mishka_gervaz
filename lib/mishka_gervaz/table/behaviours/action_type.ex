defmodule MishkaGervaz.Table.Behaviours.ActionType do
  @moduledoc """
  Behaviour for row action type renderers.

  Implement this behaviour to create custom action types that render
  buttons/links in specific ways.

  ## Example

      defmodule MyApp.ActionTypes.Confirm do
        @behaviour MishkaGervaz.Table.Behaviours.ActionType
        use Phoenix.Component
        import MishkaGervaz.Helpers, only: [humanize: 1, dynamic_component: 1]

        @impl true
        def render(assigns, action, record, ui, target) do
          assigns =
            assigns
            |> assign(:module, ui)
            |> assign(:function, :button)
            |> assign(:label, action[:ui][:label] || humanize(action[:name]))
            |> assign(:icon, action[:ui][:icon])
            |> assign(:class, action[:ui][:class] || "text-orange-600 hover:text-orange-800")
            |> assign(:record_id, record.id)
            |> assign(:target, target)
            |> assign(:confirm, action[:confirm] || "Are you sure?")

          ~H\"\"\"
          <.dynamic_component
            phx-click={@action[:event] || "confirm"}
            phx-value-id={@record_id}
            phx-target={@target}
            data-confirm={@confirm}
            {assigns}
          />
          \"\"\"
        end
      end

  Then use in DSL:

      row_actions do
        action :archive, type: MyApp.ActionTypes.Confirm, confirm: "Archive this record?"
      end

  ## Accessing State

  The `assigns` parameter includes the full table state:

  - `assigns[:state]` - The table state struct
  - `assigns[:state].config[:identity][:route]` - Base route for the resource
  - `assigns[:state].master_user?` - Whether current user is master
  """

  @doc """
  Render the action button/link.

  ## Parameters

  - `assigns` - Phoenix assigns map with `:state`, `:ui`, `:myself` keys
  - `action` - Action configuration map from DSL
  - `record` - The record this action is for
  - `ui` - UI adapter module for consistent styling
  - `target` - LiveComponent target for phx-target

  ## Returns

  Phoenix.LiveView.Rendered.t()
  """
  @callback render(
              assigns :: map(),
              action :: map(),
              record :: map(),
              ui :: module(),
              target :: any()
            ) :: Phoenix.LiveView.Rendered.t()
end
