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

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.State

      @doc """
      Process completed uploads for a given upload key.

      Consumes the uploaded entries and updates the upload state.
      """
      @spec handle_upload(State.t(), atom(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def handle_upload(state, upload_key, socket) do
        uploaded_files =
          Phoenix.LiveView.consume_uploaded_entries(socket, upload_key, fn %{path: path}, entry ->
            {:ok, %{path: path, client_name: entry.client_name, client_type: entry.client_type}}
          end)

        upload_state = Map.put(state.upload_state, upload_key, uploaded_files)
        state = State.update(state, upload_state: upload_state, dirty?: true)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      @doc """
      Cancel an in-progress upload entry.
      """
      @spec cancel_upload(State.t(), atom(), String.t(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def cancel_upload(_state, upload_key, ref, socket) do
        Phoenix.LiveView.cancel_upload(socket, upload_key, ref)
      end

      defoverridable handle_upload: 3,
                     cancel_upload: 4
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.UploadHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.UploadHandler
end
