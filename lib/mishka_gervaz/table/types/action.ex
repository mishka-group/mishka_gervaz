defmodule MishkaGervaz.Table.Types.Action do
  @moduledoc """
  Built-in action type registry.

  Provides lookup for built-in action types by atom name.
  Action types define how row action buttons are rendered.

  ## Built-in Types

  - `:link` - Navigation link
  - `:event` - Custom event button (default)
  - `:edit` - Edit action (opens form)
  - `:destroy` - Delete button with confirmation
  - `:update` - Ash update action trigger
  - `:unarchive` - Restore archived record
  - `:permanent_destroy` - Permanently delete archived record
  - `:row_click` - Full-row click handler
  - `:accordion` - Expandable row toggle (requires `:expand` feature)

  ## Custom Action Types

  Implement the `MishkaGervaz.Table.Behaviours.ActionType` behaviour:

      defmodule MyApp.ActionTypes.Archive do
        @behaviour MishkaGervaz.Table.Behaviours.ActionType
        use Phoenix.Component

        @impl true
        def render(assigns, action, record, ui, target) do
          # Return rendered HEEx
        end
      end

  Then use in DSL:

      row_actions do
        action :archive, type: MyApp.ActionTypes.Archive
      end

  See `MishkaGervaz.Table.Behaviours.TypeRegistry` (base),
  `MishkaGervaz.Table.Behaviours.ActionType`, and
  `MishkaGervaz.Table.Entities.RowAction`.
  """

  alias MishkaGervaz.Table.Types.Action

  use MishkaGervaz.Table.Behaviours.TypeRegistry,
    builtin: %{
      link: Action.Link,
      event: Action.Event,
      edit: Action.Edit,
      destroy: Action.Destroy,
      update: Action.Update,
      unarchive: Action.Unarchive,
      permanent_destroy: Action.PermanentDestroy,
      row_click: Action.RowClick,
      accordion: Action.Accordion
    },
    default: Action.Event

  @doc """
  Resolve action type module from action configuration.

  Checks in order:
  1. If type is a module with `render/4`, use it directly
  2. If type is an atom, look up in built-in registry
  3. Otherwise, default to Event action

  ## Examples

      iex> MishkaGervaz.Table.Types.Action.resolve_type(%{type: :link})
      MishkaGervaz.Table.Types.Action.Link

      iex> MishkaGervaz.Table.Types.Action.resolve_type(%{type: :destroy})
      MishkaGervaz.Table.Types.Action.Destroy
  """
  @impl true
  @spec resolve_type(map()) :: module()
  def resolve_type(action) do
    action_type = Map.get(action, :type, :event)

    cond do
      is_atom(action_type) and function_exported?(action_type, :render, 5) -> action_type
      is_atom(action_type) -> get_or_passthrough(action_type)
      true -> default()
    end
  end
end
