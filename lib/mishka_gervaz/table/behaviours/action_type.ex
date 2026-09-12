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
          master? = assigns[:state] && assigns[:state].master_user?

          assigns =
            %{__changed__: %{}}
            |> assign(:module, ui)
            |> assign(:function, :button)
            |> assign(:label, action[:ui][:label] || humanize(action[:name]))
            |> assign(:icon, action[:ui][:icon])
            |> assign(:class, action[:ui][:class] || "text-orange-600 hover:text-orange-800")
            |> assign(:phx_click, action[:event] || "confirm")
            |> assign(:phx_value_id, record.id)
            |> assign(:phx_target, target)
            |> assign(:data_confirm, (master? && action[:confirm]) || "Are you sure?")

          ~H\"\"\"
          <.dynamic_component {assigns} />
          \"\"\"
        end
      end

  Then use in DSL:

      row_actions do
        action :archive, type: MyApp.ActionTypes.Confirm, confirm: "Archive this record?"
      end

  ## What belongs in the assigns map

  Read whatever you need from the incoming `assigns`, then build a **fresh** map for the component.
  The map you build is splatted whole at the UI adapter, and `button/1` declares
  `attr :rest, :global` — so every key it does not recognise is rendered as an HTML attribute of its
  own. Passing the incoming `assigns` through would put the whole table state in the markup.

  Three kinds of key belong in it, and nothing else:

  - `:module` and `:function`, which `MishkaGervaz.Helpers.dynamic_component/1` pops off to decide
    what to call. They never reach the markup.
  - The attributes the component declares — `:label`, `:icon`, `:class`, `:variant`.
  - Bindings named `phx_*` and `data_*`, which are dashed into `phx-click`, `phx-value-id`,
    `phx-target` and `data-confirm` on the way through.

  A record id, a target or a confirm message therefore travels under its binding name —
  `:phx_value_id`, `:phx_target`, `:data_confirm` — not under a name of its own. `:record_id`,
  `:target` and `:confirm` are not attributes of anything and are rendered verbatim.

  `MishkaGervaz.Helpers.maybe_assign/3` is the way to set a key only when it has a value, so an
  absent option does not become an empty attribute.

  ## Accessing State

  The `assigns` parameter includes the full table state:

  - `assigns[:state]` - The table state struct
  - `assigns[:state].config[:identity][:route]` - Base route for the resource
  - `assigns[:state].master_user?` - Whether current user is master

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Entities.RowAction`,
  `MishkaGervaz.Table.Entities.BulkAction`, and
  `MishkaGervaz.Table.Behaviours.TypeRegistry`.
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
