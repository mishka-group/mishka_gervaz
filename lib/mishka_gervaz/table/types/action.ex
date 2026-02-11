defmodule MishkaGervaz.Table.Types.Action do
  @moduledoc """
  Built-in action type registry.

  Provides lookup for built-in action types by atom name.
  Action types define how row action buttons are rendered.

  ## Built-in Types

  - `:link` - Navigation link (show, edit)
  - `:event` - Custom event button
  - `:destroy` - Delete button with confirmation
  - `:row_click` - Row click handler

  ## Custom Action Types

  Implement the `MishkaGervaz.Table.Behaviours.ActionType` behaviour:

      defmodule MyApp.ActionTypes.Archive do
        @behaviour MishkaGervaz.Table.Behaviours.ActionType
        use Phoenix.Component

        @impl true
        def render(action, record, ui, target) do
          # Return rendered HEEx
        end
      end

  Then use in DSL:

      row_actions do
        action :archive, type: MyApp.ActionTypes.Archive
      end
  """

  alias MishkaGervaz.Table.Types.Action

  use MishkaGervaz.Table.Behaviours.TypeRegistry,
    builtin: %{
      link: Action.Link,
      event: Action.Event,
      destroy: Action.Destroy,
      update: Action.Update,
      unarchive: Action.Unarchive,
      permanent_destroy: Action.PermanentDestroy,
      row_click: Action.RowClick
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
      is_atom(action_type) and function_exported?(action_type, :render, 4) -> action_type
      is_atom(action_type) -> get_or_passthrough(action_type)
      true -> default()
    end
  end

  @doc """
  List all built-in action types.

  Alias for `builtin_types/0`.
  """
  @spec list() :: [atom()]
  def list, do: builtin_types()
end
