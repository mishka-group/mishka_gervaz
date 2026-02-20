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

      alias MishkaGervaz.Form.Web.UploadHelpers

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

      @spec sanitize_params(map(), list()) :: map()
      defp sanitize_params(params, fields) do
        case params do
          %{"form" => form_params} = p when is_map(form_params) ->
            sanitized =
              MishkaGervaz.Form.Web.Events.Builder.sanitize_typed_params(fields, form_params)

            Map.put(p, "form", sanitized)

          _ ->
            sanitization_handler().sanitize_params(params)
        end
      end

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
        params =
          params
          |> sanitize_params(state.static.fields)
          |> strip_empty_list_values()
          |> decode_constrained_map_params(state.static.fields)

        run_hook(state, :before_validate, [params, state])

        state = clear_list_field_values(state)

        socket = validation_handler().validate(state, params, socket)
        {:noreply, socket}
      end

      defp do_handle("save", params, state, socket) do
        params =
          params
          |> sanitize_params(state.static.fields)
          |> strip_empty_list_values()
          |> decode_constrained_map_params(state.static.fields)
          |> strip_empty_constrained_entries(state.static.fields)

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
        state = run_hook(state, :on_cancel, [state]) || state

        if has_hook?(state, :on_cancel) do
          send(self(), {:form_cancelled, state.static.resource})
        end

        {:noreply, reset_to_create_mode(state, socket)}
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
        if MishkaGervaz.Helpers.known_name?(step_name, state, :steps) do
          step_atom = String.to_existing_atom(step_name)
          socket = step_handler().goto_step(state, step_atom, socket)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      defp do_handle("relation_" <> action, params, state, socket) do
        relation_handler().handle(action, params, state, socket)
      end

      defp do_handle("upload_complete", %{"key" => upload_key}, state, socket) do
        if MishkaGervaz.Helpers.known_name?(upload_key, state, :uploads) do
          key_atom = String.to_existing_atom(upload_key)
          socket = upload_handler().handle_upload(state, key_atom, socket)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      defp do_handle("cancel_upload", %{"key" => upload_key, "ref" => ref}, state, socket) do
        if MishkaGervaz.Helpers.known_name?(upload_key, state, :uploads) do
          key_atom = String.to_existing_atom(upload_key)
          socket = upload_handler().cancel_upload(state, key_atom, ref, socket)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      defp do_handle(
             "delete_existing_file",
             %{"upload" => upload_name, "file-id" => file_id},
             state,
             socket
           ) do
        if MishkaGervaz.Helpers.known_name?(upload_name, state, :uploads) do
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
        else
          {:noreply, socket}
        end
      end

      defp do_handle("add_nested", %{"field" => field_name}, state, socket) do
        if MishkaGervaz.Helpers.known_name?(field_name, state) do
          case state.form do
            nil ->
              {:noreply, socket}

            form ->
              field_def = Enum.find(state.static.fields, &(to_string(&1.name) == field_name))
              json_subs = if field_def, do: json_sub_field_names(field_def), else: MapSet.new()

              current_params = AshPhoenix.Form.params(form.source)
              current_entries = get_constrained_map_entries(current_params, field_name, form)
              next_idx = to_string(length(current_entries))
              new_entry = %{}

              updated_map =
                current_entries
                |> Enum.with_index()
                |> Map.new(fn {entry, i} ->
                  {to_string(i), decode_constrained_entry(entry, json_subs)}
                end)
                |> Map.put(next_idx, new_entry)

              new_params = Map.put(current_params, field_name, updated_map)

              validated =
                form.source
                |> AshPhoenix.Form.validate(new_params)
                |> Phoenix.Component.to_form()

              show_errors? = form.source.submitted_once? or form.source.type != :create

              errors =
                if show_errors?,
                  do: validation_handler().build_errors(validated),
                  else: %{}

              state = State.update(state, form: validated, errors: errors, dirty?: true)
              {:noreply, Phoenix.Component.assign(socket, :form_state, state)}
          end
        else
          {:noreply, socket}
        end
      end

      defp do_handle("remove_nested", %{"field" => field_name, "index" => index}, state, socket) do
        if MishkaGervaz.Helpers.known_name?(field_name, state) do
          case state.form do
            nil ->
              {:noreply, socket}

            form ->
              field_def = Enum.find(state.static.fields, &(to_string(&1.name) == field_name))
              json_subs = if field_def, do: json_sub_field_names(field_def), else: MapSet.new()

              idx = String.to_integer(index)
              current_params = AshPhoenix.Form.params(form.source)
              current_entries = get_constrained_map_entries(current_params, field_name, form)
              new_entries = List.delete_at(current_entries, idx)

              reindexed =
                new_entries
                |> Enum.with_index()
                |> Map.new(fn {entry, i} ->
                  {to_string(i), decode_constrained_entry(entry, json_subs)}
                end)

              new_params = Map.put(current_params, field_name, reindexed)

              validated =
                form.source
                |> AshPhoenix.Form.validate(new_params)
                |> Phoenix.Component.to_form()

              show_errors? = form.source.submitted_once? or form.source.type != :create

              errors =
                if show_errors?,
                  do: validation_handler().build_errors(validated),
                  else: %{}

              state = State.update(state, form: validated, errors: errors, dirty?: true)
              {:noreply, Phoenix.Component.assign(socket, :form_state, state)}
          end
        else
          {:noreply, socket}
        end
      end

      defp get_constrained_map_entries(params, field_name, form) do
        key_exists? = Map.has_key?(params, field_name)

        from_params =
          case Map.get(params, field_name) do
            map when is_map(map) and not is_struct(map) ->
              map
              |> Enum.sort_by(fn {k, _} ->
                case Integer.parse(to_string(k)) do
                  {n, _} -> n
                  :error -> 0
                end
              end)
              |> Enum.map(&elem(&1, 1))

            list when is_list(list) ->
              list

            _ ->
              []
          end

        if from_params != [] do
          Enum.map(from_params, &decode_json_sub_fields/1)
        else
          if key_exists? do
            []
          else
            field_atom =
              try do
                String.to_existing_atom(field_name)
              rescue
                _ -> nil
              end

            case field_atom && Map.get(form.data || %{}, field_atom) do
              list when is_list(list) and list != [] ->
                Enum.map(list, &stringify_map_keys/1)

              _ ->
                []
            end
          end
        end
      end

      defp stringify_map_keys(map) when is_map(map) and not is_struct(map) do
        Map.new(map, fn {k, v} -> {to_string(k), v} end)
      end

      defp stringify_map_keys(other), do: other

      defp decode_json_sub_fields(entry) when is_map(entry) do
        Map.new(entry, fn {k, v} ->
          {k, maybe_decode_json(v)}
        end)
      end

      defp decode_json_sub_fields(other), do: other

      defp maybe_decode_json(v) when is_binary(v) do
        trimmed = String.trim(v)

        if (String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}")) or
             (String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]")) do
          case Jason.decode(trimmed) do
            {:ok, decoded} -> decoded
            _ -> v
          end
        else
          v
        end
      end

      defp maybe_decode_json(v), do: v

      defp do_handle("add_list_item", %{"field" => field_name}, state, socket) do
        if MishkaGervaz.Helpers.known_name?(field_name, state) do
          case state.form do
            nil ->
              {:noreply, socket}

            form ->
              field_atom = String.to_existing_atom(field_name)

              current_items =
                form
                |> Phoenix.HTML.Form.input_value(field_atom)
                |> List.wrap()
                |> Enum.reject(&(is_nil(&1) or &1 == ""))

              field_values = Map.put(state.field_values, field_atom, current_items ++ [""])
              state = State.update(state, field_values: field_values, dirty?: true)
              socket = Phoenix.Component.assign(socket, :form_state, state)
              {:noreply, socket}
          end
        else
          {:noreply, socket}
        end
      end

      defp do_handle(
             "remove_list_item",
             %{"field" => field_name, "index" => index_str},
             state,
             socket
           ) do
        if MishkaGervaz.Helpers.known_name?(field_name, state) do
          index = String.to_integer(index_str)

          case state.form do
            nil ->
              {:noreply, socket}

            form ->
              field_atom = String.to_existing_atom(field_name)

              current_items = get_list_items(form, field_atom, state.field_values)
              new_items = List.delete_at(current_items, index)

              valid_items = Enum.reject(new_items, &(is_nil(&1) or &1 == ""))
              current_params = AshPhoenix.Form.params(form.source)
              new_params = Map.put(current_params, field_name, valid_items)

              validated =
                form.source
                |> AshPhoenix.Form.validate(new_params)
                |> Phoenix.Component.to_form()

              field_values = Map.put(state.field_values, field_atom, new_items)

              state =
                validation_handler().build_errors(validated)
                |> then(
                  &State.update(state,
                    form: validated,
                    errors: &1,
                    field_values: field_values,
                    dirty?: true
                  )
                )

              socket = Phoenix.Component.assign(socket, :form_state, state)
              {:noreply, socket}
          end
        else
          {:noreply, socket}
        end
      end

      defp do_handle("field_change", %{"field" => field_name, "value" => value}, state, socket) do
        if MishkaGervaz.Helpers.known_name?(field_name, state) do
          field_atom = String.to_existing_atom(field_name)

          state =
            Map.put(state.field_values, field_atom, value)
            |> then(&State.update(state, field_values: &1, dirty?: true))

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
        else
          {:noreply, socket}
        end
      end

      defp do_handle("add_nested", %{"path" => path}, state, socket) do
        case state.form do
          nil ->
            {:noreply, socket}

          form ->
            updated =
              form.source
              |> AshPhoenix.Form.add_form(path)
              |> Phoenix.Component.to_form()

            show_errors? = form.source.submitted_once? or form.source.type != :create

            errors =
              if show_errors?,
                do: validation_handler().build_errors(updated),
                else: %{}

            state = State.update(state, form: updated, errors: errors, dirty?: true)
            {:noreply, Phoenix.Component.assign(socket, :form_state, state)}
        end
      end

      defp do_handle("remove_nested", %{"path" => path}, state, socket) do
        case state.form do
          nil ->
            {:noreply, socket}

          form ->
            updated =
              form.source
              |> AshPhoenix.Form.remove_form(path)
              |> Phoenix.Component.to_form()

            show_errors? = form.source.submitted_once? or form.source.type != :create

            errors =
              if show_errors?,
                do: validation_handler().build_errors(updated),
                else: %{}

            state = State.update(state, form: updated, errors: errors, dirty?: true)
            {:noreply, Phoenix.Component.assign(socket, :form_state, state)}
        end
      end

      defp do_handle(event, params, _state, socket) do
        send(self(), {:form_event, event, params})
        {:noreply, socket}
      end

      defp reset_to_create_mode(state, socket) do
        socket = cancel_pending_uploads(state, socket)

        reset_state =
          State.update(state,
            form: nil,
            loading: :initial,
            errors: %{},
            dirty?: false,
            existing_files: %{},
            field_values: %{},
            relation_options: %{},
            upload_state: %{}
          )

        socket
        |> Phoenix.Component.assign(:record_id, nil)
        |> DataLoader.new_record(reset_state)
      end

      defp cancel_pending_uploads(state, socket) do
        uploads = state.static.uploads || []
        component_id = state.static.id

        Enum.reduce(uploads, socket, fn upload_config, acc ->
          ns_name = UploadHelpers.namespaced_upload_name(upload_config.name, component_id)

          case acc.assigns[:uploads][ns_name] do
            %{entries: entries} when entries != [] ->
              Enum.reduce(entries, acc, fn entry, inner_acc ->
                Phoenix.LiveView.cancel_upload(inner_acc, ns_name, entry.ref)
              end)

            _ ->
              acc
          end
        end)
      end

      defp has_hook?(%{static: %{hooks: hooks}}, name) when is_map(hooks) do
        is_function(Map.get(hooks, name))
      end

      defp has_hook?(_, _), do: false

      defp get_list_items(form, field_atom, field_values) do
        case Map.get(field_values, field_atom) do
          list when is_list(list) ->
            list

          _ ->
            form
            |> Phoenix.HTML.Form.input_value(field_atom)
            |> List.wrap()
            |> Enum.reject(&is_nil/1)
        end
      end

      defp strip_empty_list_values(%{"form" => form_params} = params) when is_map(form_params) do
        cleaned =
          Map.new(form_params, fn
            {k, v} when is_list(v) -> {k, Enum.reject(v, &(&1 == ""))}
            entry -> entry
          end)

        Map.put(params, "form", cleaned)
      end

      defp strip_empty_list_values(params), do: params

      defp clear_list_field_values(state) do
        cleared = Map.reject(state.field_values, fn {_k, v} -> is_list(v) end)

        if map_size(cleared) != map_size(state.field_values) do
          State.update(state, field_values: cleared)
        else
          state
        end
      end

      defp decode_constrained_map_params(%{"form" => form_params} = params, fields)
           when is_map(form_params) do
        constrained_fields = get_constrained_fields(fields)

        decoded =
          Enum.reduce(constrained_fields, form_params, fn field, acc ->
            field_name = to_string(field.name)
            json_sub_fields = json_sub_field_names(field)

            case Map.get(acc, field_name) do
              entries when is_map(entries) and not is_struct(entries) ->
                decoded_entries =
                  Map.new(entries, fn {idx, entry} ->
                    {idx, decode_constrained_entry(entry, json_sub_fields)}
                  end)

                Map.put(acc, field_name, decoded_entries)

              _ ->
                acc
            end
          end)

        Map.put(params, "form", decoded)
      end

      defp decode_constrained_map_params(params, _fields), do: params

      defp strip_empty_constrained_entries(%{"form" => form_params} = params, fields)
           when is_map(form_params) do
        constrained_fields = get_constrained_fields(fields)

        cleaned =
          Enum.reduce(constrained_fields, form_params, fn field, acc ->
            field_name = to_string(field.name)

            case Map.get(acc, field_name) do
              entries when is_map(entries) and not is_struct(entries) ->
                cleaned_entries =
                  entries
                  |> Enum.reject(fn {_idx, entry} -> empty_entry?(entry) end)
                  |> Enum.with_index()
                  |> Map.new(fn {{_old_idx, entry}, new_idx} ->
                    {to_string(new_idx), entry}
                  end)

                Map.put(acc, field_name, cleaned_entries)

              _ ->
                acc
            end
          end)

        Map.put(params, "form", cleaned)
      end

      defp strip_empty_constrained_entries(params, _fields), do: params

      defp get_constrained_fields(fields) do
        Enum.filter(fields, fn f ->
          f.type == :nested and
            get_in(f, [Access.key(:ui), Access.key(:extra, %{})])
            |> Map.get(:nested_source) == :constrained_map
        end)
      end

      defp json_sub_field_names(field) do
        (Map.get(field, :nested_fields) || [])
        |> Enum.filter(fn nf -> nf.type == :json end)
        |> Enum.map(fn nf -> to_string(nf.name) end)
        |> MapSet.new()
      end

      defp decode_constrained_entry(entry, json_sub_fields) when is_map(entry) do
        Map.new(entry, fn {k, v} ->
          if k in json_sub_fields do
            {k, decode_json_value(v)}
          else
            {k, empty_string_to_nil(v)}
          end
        end)
      end

      defp decode_constrained_entry(entry, _), do: entry

      defp empty_string_to_nil(""), do: nil

      defp empty_string_to_nil(v) when is_binary(v) do
        if String.trim(v) == "", do: nil, else: v
      end

      defp empty_string_to_nil(v), do: v

      defp decode_json_value(""), do: nil

      defp decode_json_value(v) when is_binary(v) do
        trimmed = String.trim(v)

        if (String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}")) or
             (String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]")) do
          case Jason.decode(trimmed) do
            {:ok, decoded} -> decoded
            _ -> v
          end
        else
          v
        end
      end

      defp decode_json_value(v), do: v

      defp empty_entry?(entry) when is_map(entry) do
        Enum.all?(entry, fn {_k, v} -> blank_value?(v) end)
      end

      defp empty_entry?(_), do: true

      defp blank_value?(nil), do: true
      defp blank_value?(""), do: true

      defp blank_value?(v) when is_binary(v) do
        String.trim(v) == ""
      end

      defp blank_value?(_), do: false

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
