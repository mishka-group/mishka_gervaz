defmodule MishkaGervaz.Form.Web.Events do
  @moduledoc """
  Handles all form events for MishkaGervaz.

  This module centralizes event handling for:
  - Validation (phx-change)
  - Submission (phx-submit)
  - Wizard step navigation
  - Upload events
  - Relation field search/select
  - Cancel
  - Nested/array field management

  ## Sub-builders

  Events functionality is split into specialized sub-builders:

  - `SanitizationHandler` - Input sanitization
  - `ValidationHandler` - Form validation
  - `SubmitHandler` - Form submission
  - `StepHandler` - Wizard step navigation
  - `UploadHandler` - File upload events
  - `RelationHandler` - Relation field search/select
  - `HookRunner` - Hook execution

  ## Customization

  You can override individual sub-builders via DSL:

      mishka_gervaz do
        form do
          events do
            sanitization MyApp.CustomSanitizationHandler
            validation MyApp.CustomValidationHandler
            submit MyApp.CustomSubmitHandler
            step MyApp.CustomStepHandler
            upload MyApp.CustomUploadHandler
            hooks MyApp.CustomHookRunner
          end
        end
      end

  Or override the entire Events module:

      mishka_gervaz do
        form do
          events MyApp.CustomFormEvents
        end
      end
  """

  alias MishkaGervaz.Form.Web.{State, DataLoader}

  @type socket :: Phoenix.LiveView.Socket.t()
  @type state :: State.t()

  @callback handle(event :: String.t(), params :: map(), socket :: socket()) ::
              {:noreply, socket()}

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Form.Web.Events

      alias MishkaGervaz.Form.Web.{State, DataLoader}

      alias MishkaGervaz.Form.Web.Events.{
        SanitizationHandler,
        ValidationHandler,
        SubmitHandler,
        StepHandler,
        UploadHandler,
        RelationHandler,
        HookRunner
      }

      @spec sanitization_handler() :: module()
      defp sanitization_handler, do: SanitizationHandler.Default

      @spec validation_handler() :: module()
      defp validation_handler, do: ValidationHandler.Default

      @spec submit_handler() :: module()
      defp submit_handler, do: SubmitHandler.Default

      @spec step_handler() :: module()
      defp step_handler, do: StepHandler.Default

      @spec upload_handler() :: module()
      defp upload_handler, do: UploadHandler.Default

      @spec relation_handler() :: module()
      defp relation_handler, do: RelationHandler.Default

      @spec hook_runner() :: module()
      defp hook_runner, do: HookRunner.Default

      @spec sanitize_params(map()) :: map()
      defp sanitize_params(params), do: sanitization_handler().sanitize_params(params)

      @spec run_hook(State.t(), atom(), list()) :: any()
      defp run_hook(state, hook_name, args) do
        hook_runner().run_hook(state.static.hooks, hook_name, args)
      end

      @impl true
      def handle(event, params, socket) do
        state = socket.assigns.form_state
        do_handle(event, params, state, socket)
      end

      @spec do_handle(String.t(), map(), State.t(), Phoenix.LiveView.Socket.t()) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      defp do_handle("validate", params, state, socket) do
        params = sanitize_params(params)

        run_hook(state, :before_validate, [params, state])

        socket = validation_handler().validate(state, params, socket)
        {:noreply, socket}
      end

      defp do_handle("save", params, state, socket) do
        params = sanitize_params(params)

        case run_hook(state, :before_save, [params, state]) do
          {:halt, _reason} ->
            {:noreply, socket}

          {:cont, modified_params} ->
            socket = submit_handler().submit(state, modified_params, socket)
            {:noreply, socket}

          _ ->
            socket = submit_handler().submit(state, params, socket)
            {:noreply, socket}
        end
      end

      defp do_handle("cancel", _params, state, socket) do
        send(self(), {:form_cancelled, state.static.resource})
        {:noreply, socket}
      end

      defp do_handle("next_step", _params, state, socket) do
        socket = step_handler().advance(state, socket)
        {:noreply, socket}
      end

      defp do_handle("prev_step", _params, state, socket) do
        socket = step_handler().go_back(state, socket)
        {:noreply, socket}
      end

      defp do_handle("goto_step", %{"step" => step_name}, state, socket) do
        step_atom = String.to_existing_atom(step_name)
        socket = step_handler().goto_step(state, step_atom, socket)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("relation_search", %{"field" => field_name, "query" => query}, state, socket) do
        field_atom = String.to_existing_atom(field_name)
        socket = relation_handler().handle_search(state, field_atom, query, socket)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("relation_select", %{"field" => field_name, "value" => value}, state, socket) do
        field_atom = String.to_existing_atom(field_name)
        socket = relation_handler().handle_select(state, field_atom, value, socket)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("relation_clear", %{"field" => field_name}, state, socket) do
        field_atom = String.to_existing_atom(field_name)
        socket = relation_handler().handle_clear(state, field_atom, socket)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("upload_complete", %{"key" => upload_key}, state, socket) do
        key_atom = String.to_existing_atom(upload_key)
        socket = upload_handler().handle_upload(state, key_atom, socket)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("cancel_upload", %{"key" => upload_key, "ref" => ref}, _state, socket) do
        key_atom = String.to_existing_atom(upload_key)
        socket = upload_handler().cancel_upload(socket.assigns.form_state, key_atom, ref, socket)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle(
             "delete_existing_file",
             %{"upload" => upload_name, "file-id" => file_id},
             state,
             socket
           ) do
        name_atom = String.to_existing_atom(upload_name)

        existing = Map.get(state.existing_files, name_atom, [])

        updated =
          Enum.reject(existing, fn f ->
            to_string(f[:id] || f[:filename] || f[:name]) == file_id
          end)

        existing_files = Map.put(state.existing_files, name_atom, updated)
        state = State.update(state, existing_files: existing_files, dirty?: true)
        socket = Phoenix.Component.assign(socket, :form_state, state)
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("add_nested", %{"field" => field_name}, state, socket) do
        send(self(), {:add_nested_field, String.to_existing_atom(field_name)})
        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("remove_nested", %{"field" => field_name, "index" => index}, state, socket) do
        send(
          self(),
          {:remove_nested_field, String.to_existing_atom(field_name), String.to_integer(index)}
        )

        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle("field_change", %{"field" => field_name, "value" => value}, state, socket) do
        field_atom = String.to_existing_atom(field_name)
        field_values = Map.put(state.field_values, field_atom, value)
        state = State.update(state, field_values: field_values, dirty?: true)
        socket = Phoenix.Component.assign(socket, :form_state, state)

        dependent_fields =
          Enum.filter(state.static.fields, fn f ->
            Map.get(f, :depends_on) == field_atom
          end)

        socket =
          Enum.reduce(dependent_fields, socket, fn dep_field, acc ->
            DataLoader.load_relation_options(acc, state, dep_field.name)
          end)

        {:noreply, socket}
      rescue
        ArgumentError -> {:noreply, socket}
      end

      defp do_handle(event, params, _state, socket) do
        send(self(), {:form_event, event, params})
        {:noreply, socket}
      end

      defoverridable handle: 3
    end
  end

  @spec handle(String.t(), map(), socket()) :: {:noreply, socket()}
  def handle(event, params, socket) do
    MishkaGervaz.Form.Web.Events.Default.handle(event, params, socket)
  end
end

defmodule MishkaGervaz.Form.Web.Events.Default do
  @moduledoc false
  @dialyzer :no_match
  use MishkaGervaz.Form.Web.Events
end
