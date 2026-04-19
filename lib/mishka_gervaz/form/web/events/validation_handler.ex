defmodule MishkaGervaz.Form.Web.Events.ValidationHandler do
  @moduledoc """
  Handles form validation (phx-change events).

  ## Overridable Functions

  - `validate/3` - Validate form params and update form state
  - `build_errors/1` - Extract errors from form

  ## User Override

      defmodule MyApp.Form.ValidationHandler do
        use MishkaGervaz.Form.Web.Events.ValidationHandler

        def validate(state, params, socket) do
          # Add custom validation
          super(state, params, socket)
        end
      end
  """

  alias MishkaGervaz.Form.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.State

      @doc """
      Validate form params and update the form state.

      Called on phx-change events. Updates the AshPhoenix.Form with
      new params and extracts any validation errors.
      """
      @spec validate(State.t(), map(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def validate(state, params, socket), do: validate(state, params, socket, nil, nil)

      @spec validate(State.t(), map(), Phoenix.LiveView.Socket.t(), map() | nil) ::
              Phoenix.LiveView.Socket.t()
      def validate(state, params, socket, forced_errors),
        do: validate(state, params, socket, forced_errors, nil)

      @spec validate(State.t(), map(), Phoenix.LiveView.Socket.t(), map() | nil, list() | nil) ::
              Phoenix.LiveView.Socket.t()
      def validate(state, params, socket, forced_errors, target) do
        incoming = Map.get(params, "form", params)

        case state.form do
          nil ->
            socket

          form ->
            form_params =
              form.source
              |> AshPhoenix.Form.params()
              |> Map.merge(incoming)
              |> merge_relation_field_values(state)
              |> then(
                &MishkaGervaz.Form.Web.Events.Builder.parse_typed_params(
                  state.static.fields,
                  &1
                )
              )

            validated =
              form.source
              |> AshPhoenix.Form.validate(form_params, target: target)
              |> Phoenix.Component.to_form()

            errors =
              cond do
                is_map(forced_errors) ->
                  forced_errors

                form.source.submitted_once? or form.source.type != :create ->
                  build_errors(validated)

                true ->
                  %{}
              end

            state = State.update(state, form: validated, errors: errors, dirty?: true)
            Phoenix.Component.assign(socket, :form_state, state)
        end
      end

      @doc """
      Extract errors from a validated form.

      Returns a map of field_name => [error_messages].
      """
      @spec build_errors(Phoenix.HTML.Form.t()) :: map()
      def build_errors(form) do
        form.errors
        |> Enum.group_by(fn {field, _} -> field end, fn {_, {msg, opts}} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)
      end

      defp merge_relation_field_values(params, state) do
        state.static.fields
        |> Enum.filter(&(&1.type == :relation))
        |> Enum.reduce(params, fn field, acc ->
          case Map.get(state.field_values, field.name) do
            "__nil__" -> Map.put(acc, to_string(field.name), nil)
            v when v not in [nil, ""] -> Map.put(acc, to_string(field.name), v)
            _ -> acc
          end
        end)
      end

      defoverridable validate: 3, validate: 4, validate: 5, build_errors: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.ValidationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.ValidationHandler
end
