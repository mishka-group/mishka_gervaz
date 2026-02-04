defmodule MishkaGervaz.Table.Web.Events.HookRunner do
  @moduledoc """
  Handles hook execution for Events module.

  This module provides functions for running hooks and applying hook results.
  Hooks allow customization of event handling at specific points.

  ## Customization

  You can create a custom HookRunner:

      defmodule MyApp.CustomHookRunner do
        use MishkaGervaz.Table.Web.Events.HookRunner

        # Custom hook runner with error logging
        def run_hook(hooks, hook_name, args) do
          result = super(hooks, hook_name, args)
          case result do
            {:error, reason} -> Logger.error("Hook failed", hook: hook_name, reason: reason)
            _ -> :ok
          end
          result
        end
      end

  Then configure it in your resource's DSL:

      mishka_gervaz do
        table do
          events do
            hooks MyApp.CustomHookRunner
          end
        end
      end
  """

  @type hooks :: map() | nil
  @type hook_name :: atom() | {:on_event, String.t()} | {:on_bulk_action, String.t()}
  @type socket :: Phoenix.LiveView.Socket.t()

  @doc """
  Runs a hook with the given arguments.

  Returns the hook's return value or nil if the hook doesn't exist.
  """
  @callback run_hook(hooks :: hooks(), hook_name :: hook_name(), args :: list()) :: any()

  @doc """
  Applies a hook result to the socket.

  Handles various hook return formats:
  - `{:halt, socket}` - Stops processing and returns `{:halt, socket}`
  - `{:cont, socket}` - Continues with the returned socket
  - `socket` - Continues with the returned socket
  - `nil` or other - Uses the default socket
  """
  @callback apply_hook_result(
              hooks :: hooks(),
              hook_name :: hook_name(),
              args :: list(),
              default_socket :: socket()
            ) :: socket() | {:halt, socket()}

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.HookRunner

      @impl true
      @spec run_hook(
              map() | nil,
              atom() | {:on_event, binary()} | {:on_bulk_action, binary()},
              list()
            ) :: any()
      def run_hook(hooks, hook_name, args) when is_map(hooks) do
        case Map.get(hooks, hook_name) do
          func when is_function(func) ->
            apply(func, args)

          _ ->
            nil
        end
      end

      def run_hook(_, _, _), do: nil

      @impl true
      @spec apply_hook_result(
              map() | nil,
              atom() | {:on_event, binary()} | {:on_bulk_action, binary()},
              list(),
              Phoenix.LiveView.Socket.t()
            ) :: Phoenix.LiveView.Socket.t() | {:halt, Phoenix.LiveView.Socket.t()}
      def apply_hook_result(hooks, hook_name, args, default_socket) do
        case run_hook(hooks, hook_name, args) do
          {:halt, socket} ->
            {:halt, socket}

          {:cont, socket} ->
            socket

          socket when is_struct(socket, Phoenix.LiveView.Socket) ->
            socket

          _ ->
            default_socket
        end
      end

      defoverridable run_hook: 3, apply_hook_result: 4
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.HookRunner.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.HookRunner
end
