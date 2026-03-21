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
  alias MishkaGervaz.Form.Web.UploadHelpers

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.{State, DataLoader}
      alias MishkaGervaz.Form.Web.UploadHelpers

      @doc """
      Submit the form for create or update.

      Submits the AshPhoenix.Form and handles success/error.
      Consumes uploaded files and merges them into params before submission.
      """
      @spec submit(State.t(), map(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def submit(state, params, socket) do
        incoming = Map.get(params, "form", params)

        form_params =
          case state.form do
            nil ->
              incoming

            form ->
              form.source
              |> AshPhoenix.Form.params()
              |> Map.merge(incoming)
              |> merge_relation_field_values(state)
          end

        form_params = transform_params(state, form_params)
        form_params = merge_defaults(state, form_params)
        form_params = drop_protected_fields(state, form_params)

        {socket, form_params} = consume_and_merge_uploads(state, form_params, socket)

        case state.form do
          nil ->
            socket

          form ->
            result =
              AshPhoenix.Form.submit(form.source,
                params: form_params,
                force?: true
              )

            cleanup_temp_uploads(form_params)

            case result do
              {:ok, record} ->
                after_save(state, record, socket)

              {:error, updated_form} ->
                updated_form = Phoenix.Component.to_form(updated_form)
                errors = build_submit_errors(updated_form)
                field_names = MapSet.new(state.static.fields, & &1.name)
                form_errors = extract_form_level_errors(updated_form, field_names)

                state =
                  State.update(state,
                    form: updated_form,
                    errors: errors,
                    form_errors: form_errors
                  )

                record_id = socket.assigns[:record_id]

                socket
                |> Phoenix.Component.assign(:form_state, state)
                |> push_js_hook(state, :on_error, record_id)
            end
        end
      end

      @doc """
      Transform params before submission.

      Override this to add computed fields, strip unwanted params, etc.
      """
      @spec transform_params(State.t(), map()) :: map()
      def transform_params(state, params) do
        MishkaGervaz.Form.Web.Events.Builder.parse_typed_params(state.static.fields, params)
      end

      @doc """
      Handle post-save logic.

      By default, sends a message to the parent LiveView.
      """
      @spec after_save(State.t(), struct(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def after_save(state, result, socket) do
        record_id = Map.get(result, :id)
        send(self(), {:form_saved, state.mode, result})

        socket = push_js_hook(socket, state, :after_save, record_id)

        reset_state =
          State.update(state,
            form: nil,
            loading: :initial,
            errors: %{},
            form_errors: [],
            dirty?: false,
            existing_files: %{},
            field_values: %{},
            relation_options: %{}
          )

        socket
        |> Phoenix.Component.assign(:record_id, nil)
        |> DataLoader.new_record(reset_state)
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

      @spec extract_form_level_errors(Phoenix.HTML.Form.t(), MapSet.t()) :: list(String.t())
      defp extract_form_level_errors(form, field_names) do
        form.errors
        |> Enum.reject(fn {field, _} -> MapSet.member?(field_names, field) end)
        |> Enum.map(fn {_field, {msg, opts}} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)
      end

      @spec consume_and_merge_uploads(State.t(), map(), Phoenix.LiveView.Socket.t()) ::
              {Phoenix.LiveView.Socket.t(), map()}
      def consume_and_merge_uploads(%{static: %{uploads: uploads}} = state, form_params, socket)
          when is_list(uploads) and uploads != [] do
        Enum.reduce(uploads, {socket, form_params}, fn upload_config, {sock, params} ->
          ns_name = UploadHelpers.namespaced_upload_name(upload_config.name, state.static.id)
          consume_upload_entries(sock, params, ns_name, upload_config)
        end)
      end

      def consume_and_merge_uploads(_state, form_params, socket), do: {socket, form_params}

      defp consume_upload_entries(socket, params, ns_name, upload_config) do
        registered_uploads = socket.assigns[:uploads] || %{}

        case Map.fetch(registered_uploads, ns_name) do
          {:ok, _} ->
            uploaded_files =
              Phoenix.LiveView.consume_uploaded_entries(socket, ns_name, fn %{path: path},
                                                                            entry ->
                dest =
                  Path.join(
                    System.tmp_dir!(),
                    "gervaz_#{System.unique_integer([:positive])}_#{entry.client_name}"
                  )

                File.cp!(path, dest)

                {:ok,
                 %{
                   path: dest,
                   client_name: entry.client_name,
                   client_type: entry.client_type,
                   client_size: entry.client_size
                 }}
              end)

            merge_uploaded_files(socket, params, upload_config, uploaded_files)

          :error ->
            {socket, params}
        end
      end

      defp merge_uploaded_files(socket, params, _upload_config, []), do: {socket, params}

      defp merge_uploaded_files(socket, params, upload_config, uploaded_files) do
        param_key = to_string(upload_config[:field] || upload_config.name)
        {socket, Map.put(params, param_key, uploaded_files)}
      end

      defp cleanup_temp_uploads(form_params) do
        tmp_dir = System.tmp_dir!()

        form_params
        |> Enum.each(fn
          {_key, files} when is_list(files) ->
            Enum.each(files, fn
              %{path: path} when is_binary(path) ->
                if String.starts_with?(path, tmp_dir), do: File.rm(path)

              _ ->
                :ok
            end)

          _ ->
            :ok
        end)
      end

      defp push_js_hook(socket, state, hook_name, record_id) do
        case state.static do
          %{hooks: %{js: %{^hook_name => func}}} when is_function(func, 1) ->
            js = func.(record_id)

            Phoenix.LiveView.push_event(socket, "gervaz:exec-js", %{
              js: Jason.encode!(js),
              target: state.static.id <> "-form-wrapper"
            })

          _ ->
            socket
        end
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

      @spec drop_protected_fields(State.t(), map()) :: map()
      @spec merge_defaults(State.t(), map()) :: map()
      defp merge_defaults(%{mode: :create, defaults: defaults}, params)
           when is_map(defaults) and defaults != %{} do
        defaults
        |> Enum.reduce(params, fn {key, value}, acc ->
          str_key = to_string(key)

          if Map.has_key?(acc, str_key) and acc[str_key] not in [nil, ""] do
            acc
          else
            Map.put(acc, str_key, value)
          end
        end)
      end

      defp merge_defaults(_state, params), do: params

      defp drop_protected_fields(state, params) do
        state.static.fields
        |> Enum.reduce(params, fn field, acc ->
          field_key = to_string(field.name)

          cond do
            field_restricted?(field, state) -> Map.delete(acc, field_key)
            field_readonly?(field, state) -> Map.delete(acc, field_key)
            true -> acc
          end
        end)
      end

      defp field_restricted?(%{restricted: true}, %{master_user?: false}), do: true

      defp field_restricted?(%{restricted: f}, state) when is_function(f, 1),
        do: not f.(state)

      defp field_restricted?(_, _), do: false

      defp field_readonly?(%{readonly: f}, state) when is_function(f, 1), do: f.(state)
      defp field_readonly?(%{readonly: true}, _), do: true
      defp field_readonly?(_, _), do: false

      defoverridable submit: 3, transform_params: 2, after_save: 3, consume_and_merge_uploads: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.SubmitHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.SubmitHandler
end
