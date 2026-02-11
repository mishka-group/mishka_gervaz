defmodule MishkaGervaz.Form.Web.Events.SubmitHandler do
  @moduledoc """
  Handles form submission (phx-submit events).

  ## Overridable Functions

  - `submit/3` - Submit the form (create or update)
  - `transform_params/2` - Transform params before submission
  - `after_save/3` - Handle post-save logic

  ## User Override

      defmodule MyApp.Form.SubmitHandler do
        use MishkaGervaz.Form.Web.Events.SubmitHandler

        def transform_params(state, params) do
          params |> super(state) |> Map.put("custom_field", "value")
        end
      end
  """

  alias MishkaGervaz.Form.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.State

      @doc """
      Submit the form for create or update.

      Submits the AshPhoenix.Form and handles success/error.
      """
      @spec submit(State.t(), map(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def submit(state, params, socket) do
        form_params = transform_params(state, Map.get(params, "form", params))

        case state.form do
          nil ->
            socket

          form ->
            case AshPhoenix.Form.submit(form.source, params: form_params) do
              {:ok, result} ->
                after_save(state, result, socket)

              {:error, updated_form} ->
                updated_form = Phoenix.Component.to_form(updated_form)
                errors = build_submit_errors(updated_form)
                state = State.update(state, form: updated_form, errors: errors)
                Phoenix.Component.assign(socket, :form_state, state)
            end
        end
      end

      @doc """
      Transform params before submission.

      Override this to add computed fields, strip unwanted params, etc.
      """
      @spec transform_params(State.t(), map()) :: map()
      def transform_params(_state, params), do: params

      @doc """
      Handle post-save logic.

      By default, sends a message to the parent LiveView.
      """
      @spec after_save(State.t(), struct(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def after_save(state, result, socket) do
        send(self(), {:form_saved, state.mode, result})

        state = State.update(state, dirty?: false)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      @spec build_submit_errors(Phoenix.HTML.Form.t()) :: map()
      defp build_submit_errors(form) do
        form.errors
        |> Enum.group_by(fn {field, _} -> field end, fn {_, {msg, opts}} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)
      end

      defoverridable submit: 3,
                     transform_params: 2,
                     after_save: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.SubmitHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.SubmitHandler
end
