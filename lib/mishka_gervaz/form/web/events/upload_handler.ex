defmodule MishkaGervaz.Form.Web.Events.UploadHandler do
  @moduledoc """
  Handles file upload events.

  ## Overridable Functions

  - `handle_upload/3` - Process completed uploads
  - `cancel_upload/3` - Cancel an in-progress upload

  ## User Override

      defmodule MyApp.Form.UploadHandler do
        use MishkaGervaz.Form.Web.Events.UploadHandler

        def handle_upload(state, upload_key, socket) do
          # Custom upload processing
          super(state, upload_key, socket)
        end
      end
  """

  alias MishkaGervaz.Form.Web.State
  alias MishkaGervaz.Form.Web.UploadHelpers

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.State
      alias MishkaGervaz.Form.Web.UploadHelpers

      @doc """
      Process completed uploads for a given upload key.

      Resolves namespaced upload name, consumes entries, and updates upload state.
      """
      @spec handle_upload(State.t(), atom(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def handle_upload(state, upload_key, socket) do
        ns_name = resolve_upload_name(state, upload_key)

        uploaded_files =
          Phoenix.LiveView.consume_uploaded_entries(socket, ns_name, fn %{path: path}, entry ->
            {:ok, %{path: path, client_name: entry.client_name, client_type: entry.client_type}}
          end)

        upload_state = Map.put(state.upload_state, upload_key, uploaded_files)
        state = State.update(state, upload_state: upload_state, dirty?: true)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      @doc """
      Cancel an in-progress upload entry.

      Resolves namespaced upload name before cancelling.
      """
      @spec cancel_upload(State.t(), atom(), String.t(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def cancel_upload(state, upload_key, ref, socket) do
        ns_name = resolve_upload_name(state, upload_key)
        Phoenix.LiveView.cancel_upload(socket, ns_name, ref)
      end

      defp resolve_upload_name(%{static: %{id: id}}, upload_key) do
        UploadHelpers.namespaced_upload_name(upload_key, id)
      end

      defp resolve_upload_name(_state, upload_key), do: upload_key

      defoverridable handle_upload: 3, cancel_upload: 4
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.UploadHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.UploadHandler
end
