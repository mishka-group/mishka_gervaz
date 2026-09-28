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

  Top-level helpers (`format_form_errors/1`, `extract_form_level_errors/2`,
  `save_errors/2`, `cleanup_temp_uploads/1`, `push_js_hook/4`, `merge_defaults/2`,
  `drop_protected_fields/2`, `field_restricted?/2`, `field_readonly?/2`)
  are public so user overrides can reuse them — they live outside the
  `__using__` macro to avoid per-consumer compile cost.

  See `MishkaGervaz.Form.Web.Events`,
  `MishkaGervaz.Form.Web.Events.Helpers` (for `parse_typed_params/2` and
  `merge_uploaded_files/4`),
  `MishkaGervaz.Form.Web.DataLoader`,
  `MishkaGervaz.Form.Web.UploadHelpers`, and the sibling sub-handlers.
  """

  use MishkaGervaz.Messages

  alias MishkaGervaz.Form.Web.State
  alias MishkaGervaz.Form.Web.UploadHelpers
  alias MishkaGervaz.Form.Web.DataLoader.Helpers, as: DataLoaderHelpers

  @doc false
  @spec format_form_errors(Phoenix.HTML.Form.t()) :: map()
  def format_form_errors(form) do
    form.errors
    |> Enum.group_by(fn {field, _} -> field end, fn {_, {msg, opts}} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc false
  @spec extract_form_level_errors(Phoenix.HTML.Form.t(), MapSet.t()) :: list(String.t())
  def extract_form_level_errors(form, field_names) do
    form.errors
    |> Enum.reject(fn {field, _} -> MapSet.member?(field_names, field) end)
    |> Enum.map(fn {_field, {msg, opts}} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  The errors a failed save shows, as `{field_errors, form_errors}`.

  `field_errors` maps a field name to its messages and `form_errors` lists the messages no field
  shows. An error under a field that has no nested form, such as one id of a relation field's
  `[:tag_ids, 0]`, is shown on that field. When the save failed and none of its errors can be shown,
  `form_errors` holds one message saying the changes were not saved.
  """
  @spec save_errors(AshPhoenix.Form.t(), MapSet.t()) :: {map(), list(String.t())}
  def save_errors(ash_form, field_names) do
    form = Phoenix.Component.to_form(ash_form)

    {nested_field_errors, nested_form_errors} =
      ash_form
      |> AshPhoenix.Form.raw_errors()
      |> Enum.flat_map(&path_error(&1, ash_form.form_keys))
      |> Enum.split_with(fn {field, _msg} -> MapSet.member?(field_names, field) end)

    field_errors =
      Enum.reduce(nested_field_errors, format_form_errors(form), fn {field, msg}, acc ->
        Map.update(acc, field, [msg], &(&1 ++ [msg]))
      end)

    form_errors =
      extract_form_level_errors(form, field_names) ++ Enum.map(nested_form_errors, &elem(&1, 1))

    if field_errors == %{} and form_errors == [] do
      {field_errors, [dgettext("mishka_gervaz", "The changes were not saved.")]}
    else
      {field_errors, form_errors}
    end
  end

  defp path_error(%{path: [key | _]} = error, form_keys) when is_atom(key) do
    if Keyword.has_key?(form_keys, key) or is_nil(AshPhoenix.FormData.Error.impl_for(error)) do
      []
    else
      error
      |> AshPhoenix.FormData.Error.to_form_error()
      |> List.wrap()
      |> Enum.map(fn {_field, msg, vars} -> {key, interpolate(msg, vars)} end)
    end
  end

  defp path_error(_error, _form_keys), do: []

  defp interpolate(msg, vars) do
    Enum.reduce(vars, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  @doc false
  @spec cleanup_temp_uploads(map()) :: :ok
  def cleanup_temp_uploads(form_params) do
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

  @doc false
  @spec push_js_hook(Phoenix.LiveView.Socket.t(), map(), atom(), any()) ::
          Phoenix.LiveView.Socket.t()
  def push_js_hook(socket, state, hook_name, record_id) do
    case state.static do
      %{hooks: %{js: %{^hook_name => func}}} when is_function(func, 1) ->
        js = func.(record_id)

        Phoenix.LiveView.push_event(socket, "gervaz:exec-js", %{
          js: Jason.encode!(js.ops),
          target: state.static.id <> "-form-wrapper"
        })

      _ ->
        socket
    end
  end

  @doc """
  Fills each param a create form left `nil` or `""` from `state.defaults`.

  A default is left out when its field no longer holds, in `state.field_values`, the value the form
  was built with. A picker cleared on screen, or emptied because a picker it depends on changed, is
  saved empty rather than with its default. Update forms are returned unchanged.
  """
  @spec merge_defaults(map(), map()) :: map()
  def merge_defaults(%{mode: :create, defaults: defaults} = state, params)
      when is_map(defaults) and defaults != %{} do
    moved = moved_fields(state)

    Enum.reduce(defaults, params, fn {key, value}, acc ->
      str_key = to_string(key)

      cond do
        MapSet.member?(moved, str_key) -> acc
        Map.has_key?(acc, str_key) and acc[str_key] not in [nil, ""] -> acc
        true -> Map.put(acc, str_key, value)
      end
    end)
  end

  def merge_defaults(_state, params), do: params

  defp moved_fields(%{static: %{fields: fields}, field_values: field_values} = state) do
    built_with = DataLoaderHelpers.extract_defaults_to_field_values(state)

    fields
    |> Enum.reject(&(Map.get(field_values, &1.name) == Map.get(built_with, &1.name)))
    |> MapSet.new(&to_string(&1.name))
  end

  @doc false
  @spec drop_protected_fields(map(), map()) :: map()
  def drop_protected_fields(state, params) do
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

  @doc false
  @spec field_restricted?(map(), map()) :: boolean()
  def field_restricted?(%{restricted: true}, %{master_user?: true}), do: false
  def field_restricted?(%{restricted: true}, _state), do: true

  def field_restricted?(%{restricted: f}, state) when is_function(f, 1),
    do: not f.(state)

  def field_restricted?(_, _), do: false

  @doc false
  @spec field_readonly?(map(), map()) :: boolean()
  defdelegate field_readonly?(field, state), to: State.Helpers

  defmacro __using__(_opts) do
    quote do
      alias MishkaGervaz.Form.Web.{State, DataLoader}
      alias MishkaGervaz.Form.Web.UploadHelpers
      alias MishkaGervaz.Form.Web.Events.Helpers, as: EventsHelpers

      import MishkaGervaz.Helpers, only: [merge_relation_field_values: 2]

      import MishkaGervaz.Form.Web.Events.SubmitHandler,
        only: [
          format_form_errors: 1,
          extract_form_level_errors: 2,
          save_errors: 2,
          cleanup_temp_uploads: 1,
          push_js_hook: 4,
          merge_defaults: 2,
          drop_protected_fields: 2
        ]

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
        form_params = drop_protected_fields(state, form_params)
        form_params = merge_defaults(state, form_params)

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
                field_names = MapSet.new(state.static.fields, & &1.name)
                {errors, form_errors} = save_errors(updated_form, field_names)

                state =
                  State.update(state,
                    form: Phoenix.Component.to_form(updated_form),
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
        EventsHelpers.parse_typed_params(state.static.fields, params)
      end

      @doc """
      Handle post-save logic.

      Sends `{:form_saved, mode, record}` to the parent LiveView and runs the `after_save` JS hook.
      An update save on a form mounted with a `record_id` assign reloads the saved record for
      editing; every other save returns the form to an empty create form.
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

        if state.mode == :update and socket.assigns[:record_id_given?] == true and
             not is_nil(record_id) do
          socket
          |> Phoenix.Component.assign(:record_id, record_id)
          |> DataLoader.load_record(reset_state, record_id)
        else
          socket
          |> Phoenix.Component.assign(:record_id, nil)
          |> DataLoader.new_record(reset_state)
        end
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

            EventsHelpers.merge_uploaded_files(socket, params, upload_config, uploaded_files)

          :error ->
            {socket, params}
        end
      end

      defoverridable submit: 3, transform_params: 2, after_save: 3, consume_and_merge_uploads: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.SubmitHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.SubmitHandler
end
