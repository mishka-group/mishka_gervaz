defmodule MishkaGervaz.Table.Web.AutoState do
  @moduledoc """
  Built-in state-transition rules for tables.

  Configured under the `hooks.builtins` DSL section. Each rule is opt-in
  (default `false`) except `:clear_selection_after_bulk` which defaults to
  `true` because it matches existing behavior.

  Rules:
    * `:switch_to_active_on_empty_archive` — after a successful unarchive /
      permanent_destroy in `:archived` mode, switch to `:active` mode once the
      archive list is observed empty on the next load.
    * `:switch_to_archive_on_empty_active` — symmetric (rare; opt-in).
    * `:clear_selection_after_bulk` — read by the bulk action handler.
    * `:reset_page_on_empty_current_page` — if the current page becomes empty
      and `page > 1`, reload page 1.
    * `:redirect_on_empty` — when `total_count == 0` after a load, navigate to
      a path (string) or `fn state -> path end`.

  ## Flow

  Row actions don't normally reload, so `after_row_action/3` triggers a reload
  when any rule is enabled and stores `:armed_action` on the socket assigns.
  Bulk actions already reload; `after_bulk_action/3` just arms the flag.
  `after_load/2` (called from `DataLoader.handle_async`) reads the armed flag,
  applies the relevant rule, and clears the flag.
  """

  alias MishkaGervaz.Table.Web.{State, DataLoader}

  @type socket :: Phoenix.LiveView.Socket.t()

  @armed_key :__auto_state_armed__

  @spec config(State.t()) :: map()
  def config(%State{static: %{hooks: %{__builtins__: %{} = b}}}), do: b
  def config(_state), do: %{clear_selection_after_bulk: true}

  @spec enabled?(State.t(), atom()) :: boolean()
  def enabled?(state, key), do: Map.get(config(state), key) == true

  @spec value(State.t(), atom()) :: term()
  def value(state, key), do: Map.get(config(state), key)

  @doc """
  Apply rules after a row action completed.

  If any rule is enabled, arm the socket and trigger a fresh load so
  `after_load/2` can react to the new `total_count`.
  """
  @spec after_row_action(socket(), State.t(), atom()) :: socket()
  def after_row_action(socket, state, action_name) do
    if any_post_load_rule_enabled?(state) do
      socket
      |> arm(action_name, :row)
      |> DataLoader.load_async(state, page: state.page, reset: true)
    else
      socket
    end
  end

  @doc """
  Arm flags after a bulk action — the bulk handler already triggers a reload.
  """
  @spec after_bulk_action(socket(), State.t(), map() | nil) :: socket()
  def after_bulk_action(socket, state, %{name: name}) do
    if any_post_load_rule_enabled?(state),
      do: arm(socket, name, :bulk),
      else: socket
  end

  def after_bulk_action(socket, _state, _action), do: socket

  @doc """
  Apply built-in rules right after `DataLoader.handle_async` finishes loading.
  """
  @spec after_load(socket(), State.t()) :: socket()
  def after_load(socket, state) do
    {action, _kind, socket} = pop_armed(socket)

    socket
    |> maybe_switch_archive_mode(state, action)
    |> maybe_reset_to_first_page(state)
    |> maybe_redirect_on_empty(state)
  end

  defp arm(socket, action_name, kind) do
    Phoenix.Component.assign(socket, @armed_key, %{action: action_name, kind: kind})
  end

  defp pop_armed(socket) do
    case Map.get(socket.assigns, @armed_key) do
      %{action: action, kind: kind} ->
        socket = Phoenix.Component.assign(socket, @armed_key, nil)
        {action, kind, socket}

      _ ->
        {nil, nil, socket}
    end
  end

  defp any_post_load_rule_enabled?(state) do
    enabled?(state, :switch_to_active_on_empty_archive) or
      enabled?(state, :switch_to_archive_on_empty_active) or
      enabled?(state, :reset_page_on_empty_current_page) or
      not is_nil(value(state, :redirect_on_empty))
  end

  defp maybe_switch_archive_mode(socket, _state, nil), do: socket

  defp maybe_switch_archive_mode(socket, state, action_name) do
    cond do
      state.archive_status == :archived and
        action_name in [:unarchive, :permanent_destroy] and
        enabled?(state, :switch_to_active_on_empty_archive) and
          state.total_count in [0, nil] ->
        DataLoader.apply_archive_status(socket, state, :active)

      state.archive_status == :active and
        action_name in [:delete, :destroy] and
        enabled?(state, :switch_to_archive_on_empty_active) and
          state.total_count in [0, nil] ->
        DataLoader.apply_archive_status(socket, state, :archived)

      true ->
        socket
    end
  end

  defp maybe_reset_to_first_page(socket, state) do
    if enabled?(state, :reset_page_on_empty_current_page) and state.page > 1 and
         state.total_count == 0 do
      DataLoader.load_async(socket, state, page: 1, reset: true)
    else
      socket
    end
  end

  defp maybe_redirect_on_empty(socket, state) do
    case value(state, :redirect_on_empty) do
      nil ->
        socket

      _ when state.total_count != 0 ->
        socket

      path when is_binary(path) ->
        Phoenix.LiveView.push_navigate(socket, to: path)

      fun when is_function(fun, 1) ->
        case fun.(state) do
          path when is_binary(path) -> Phoenix.LiveView.push_navigate(socket, to: path)
          _ -> socket
        end
    end
  end
end
