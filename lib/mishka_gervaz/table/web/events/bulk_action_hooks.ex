defmodule MishkaGervaz.Table.Web.Events.BulkActionHooks do
  @moduledoc """
  Helpers for bulk-action lifecycle hook authors.

  The 3-arity variants of `:on_bulk_action_success` and
  `:on_bulk_action_error` (and the unarchive conflict-skip success branch)
  receive `(summary, state, socket)` and can return either:

    * a plain `socket` — the core handler then fires its default flash
      (e.g. `"3 succeeded, 2 failed"` on partial, or the error flash).
    * `{:halt, socket}` — the core handler skips the default flash; the
      hook is fully responsible for messaging.

  Use `silence/1` for the halt path and (optionally) `use_default/1` as a
  documentation-friendly no-op when you want the default flash to fire.

  ## Examples

  Replace the default with a custom message:

      hooks do
        on_bulk_action_success :master_unarchive, fn summary, _state, socket ->
          socket
          |> Phoenix.LiveView.put_flash(:info, "Restored \#{summary.succeeded_count} components.")
          |> MishkaGervaz.Table.Web.Events.BulkActionHooks.silence()
        end
      end

  Suppress the error flash entirely (e.g. log it instead):

      on_bulk_action_error :destroy, fn summary, _state, socket ->
        Logger.warning("destroy failed: \#{inspect(summary.failed_errors)}")
        MishkaGervaz.Table.Web.Events.BulkActionHooks.silence(socket)
      end

  Let the default fire and just observe:

      on_bulk_action_success :destroy, fn summary, _state, socket ->
        :telemetry.execute([:my_app, :destroy, :success], %{count: summary.succeeded_count})
        socket
      end

  ## Customization

  Like the sibling handlers in `events/`, the helpers are overridable:

      defmodule MyApp.BulkActionHooks do
        use MishkaGervaz.Table.Web.Events.BulkActionHooks

        # Wrap silence/1 with logging
        def silence(socket) do
          Logger.debug("default bulk flash suppressed")
          super(socket)
        end
      end

  See `MishkaGervaz.Table.Web.Events.BulkActionResult` for the summary
  shape, and `MishkaGervaz.Table.Web.Events.BulkActionHandler` for the
  full lifecycle.
  """

  @doc "Halts the core handler's default flash; the hook owns messaging."
  @callback silence(Phoenix.LiveView.Socket.t()) ::
              {:halt, Phoenix.LiveView.Socket.t()}

  @doc "Continues with the core handler's default flash; documentation-friendly alias for returning the socket unchanged."
  @callback use_default(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()

  @doc """
  Sets a flash message that reliably reaches the parent LiveView.

  Use this from a bulk hook rather than `Phoenix.LiveView.put_flash/3`, which
  sets the flash on the component only.

  It sends `{:put_flash, kind, msg}` to the LiveView process; admin pages have
  a `handle_info/2` bridge that calls `put_flash/3` on the parent.
  """
  @callback put_flash(Phoenix.LiveView.Socket.t(), atom(), String.t()) ::
              Phoenix.LiveView.Socket.t()

  @doc """
  Convenience entry point delegating to `__MODULE__.Default.silence/1`.
  """
  @spec silence(Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()}
  defdelegate silence(socket), to: __MODULE__.Default

  @doc """
  Convenience entry point delegating to `__MODULE__.Default.use_default/1`.
  """
  @spec use_default(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate use_default(socket), to: __MODULE__.Default

  @doc """
  Convenience entry point delegating to `__MODULE__.Default.put_flash/3`.
  """
  @spec put_flash(Phoenix.LiveView.Socket.t(), atom(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate put_flash(socket, kind, msg), to: __MODULE__.Default

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.BulkActionHooks

      @impl true
      def silence(socket), do: {:halt, socket}

      @impl true
      def use_default(socket), do: socket

      @impl true
      def put_flash(socket, kind, msg) do
        send(self(), {:put_flash, kind, msg})
        socket
      end

      defoverridable silence: 1, use_default: 1, put_flash: 3
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.BulkActionHooks.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.BulkActionHooks
end
