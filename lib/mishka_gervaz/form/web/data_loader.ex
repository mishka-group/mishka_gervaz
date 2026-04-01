defmodule MishkaGervaz.Form.Web.DataLoader do
  @moduledoc """
  Handles async data loading for MishkaGervaz forms.

  This module manages:
  - Loading records for edit mode
  - Creating new AshPhoenix.Form for create mode
  - Loading relation options for select fields
  - Async result handling

  ## Sub-builders

  DataLoader is composed of sub-builders that can be overridden:

  - `RecordLoader` - Loads/creates AshPhoenix.Form
  - `TenantResolver` - Resolves tenant and actions
  - `RelationLoader` - Loads options for relation fields
  - `HookRunner` - Executes lifecycle hooks

  ## User Override

  Override the entire data_loader module:

      defmodule MyApp.Form.DataLoader do
        use MishkaGervaz.Form.Web.DataLoader

        def load_record(socket, state, record_id) do
          # Custom loading logic
          super(socket, state, record_id)
        end
      end

  Override specific sub-builders:

      defmodule MyApp.Form.DataLoader do
        use MishkaGervaz.Form.Web.DataLoader,
          record: MyApp.Form.RecordLoader,
          relation: MyApp.Form.RelationLoader
      end
  """

  alias MishkaGervaz.Form.Web.State

  require Phoenix.LiveView

  @spec load_record(Phoenix.LiveView.Socket.t(), State.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate load_record(socket, state, record_id), to: __MODULE__.Default

  @spec new_record(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate new_record(socket, state), to: __MODULE__.Default

  @spec load_relation_options(Phoenix.LiveView.Socket.t(), State.t(), atom()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate load_relation_options(socket, state, field_name), to: __MODULE__.Default

  @spec search_relation_options(Phoenix.LiveView.Socket.t(), State.t(), atom(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate search_relation_options(socket, state, field_name, search_term),
    to: __MODULE__.Default

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias MishkaGervaz.Form.Web.State

      require Phoenix.LiveView

      @__record_loader__ Keyword.get(
                           opts,
                           :record,
                           MishkaGervaz.Form.Web.DataLoader.RecordLoader.Default
                         )
      @__tenant_resolver__ Keyword.get(
                             opts,
                             :tenant,
                             MishkaGervaz.Form.Web.DataLoader.TenantResolver.Default
                           )
      @__relation_loader__ Keyword.get(
                             opts,
                             :relation,
                             MishkaGervaz.Form.Web.DataLoader.RelationLoader.Default
                           )
      @__hook_runner__ Keyword.get(
                         opts,
                         :hooks,
                         MishkaGervaz.Form.Web.DataLoader.HookRunner.Default
                       )

      @spec record_loader() :: module()
      def record_loader, do: @__record_loader__

      @spec tenant_resolver() :: module()
      def tenant_resolver, do: @__tenant_resolver__

      @spec relation_loader() :: module()
      def relation_loader, do: @__relation_loader__

      @spec hook_runner() :: module()
      def hook_runner, do: @__hook_runner__

      @doc """
      Load an existing record for editing.

      Starts an async task to load the record and build an AshPhoenix.Form.
      """
      @spec load_record(Phoenix.LiveView.Socket.t(), State.t(), String.t()) ::
              Phoenix.LiveView.Socket.t()
      def load_record(socket, state, record_id) do
        tenant = tenant_resolver().get_tenant(state)
        actor = state.current_user
        record_mod = record_loader()

        state = State.update(state, loading: :loading, mode: :update)

        socket
        |> Phoenix.Component.assign(:form_state, state)
        |> Phoenix.LiveView.start_async(:load_record, fn ->
          record_mod.load_for_edit(state, record_id, tenant: tenant, actor: actor)
        end)
      end

      @doc """
      Create a new empty form for creating a record.

      Synchronously builds the form since no database query is needed.
      """
      @spec new_record(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
      def new_record(socket, state) do
        tenant = tenant_resolver().get_tenant(state)
        actor = state.current_user
        record_mod = record_loader()

        case record_mod.new_for_create(state, tenant: tenant, actor: actor) do
          {:ok, form} ->
            form = run_on_init_hook(state, form)
            field_values = extract_defaults_to_field_values(state)

            state =
              State.update(state,
                form: form,
                loading: :loaded,
                mode: :create,
                field_values: field_values
              )

            socket
            |> Phoenix.Component.assign(:form_state, state)
            |> load_dependent_relations(state)
            |> load_readonly_relation_options(state)

          {:error, _reason} ->
            state = State.update(state, loading: :error, mode: :create)
            Phoenix.Component.assign(socket, :form_state, state)
        end
      end

      @doc """
      Load options for a relation field.

      Starts an async task to load the options.
      """
      @spec load_relation_options(Phoenix.LiveView.Socket.t(), State.t(), atom()) ::
              Phoenix.LiveView.Socket.t()
      def load_relation_options(socket, state, field_name) do
        field = find_field(state, field_name)

        if field do
          tenant = tenant_resolver().get_tenant(state)
          relation_mod = relation_loader()

          current_opts = Map.get(state.relation_options, field_name, %{})

          relation_options =
            Map.put(state.relation_options, field_name, Map.put(current_opts, :loading?, true))

          state = State.update(state, relation_options: relation_options)

          socket
          |> Phoenix.Component.assign(:form_state, state)
          |> Phoenix.LiveView.start_async(
            {:load_relation, field_name},
            fn ->
              relation_mod.load_options(field, state, tenant: tenant)
            end
          )
        else
          socket
        end
      end

      @doc """
      Search options for a relation field with a query string.
      """
      @spec search_relation_options(
              Phoenix.LiveView.Socket.t(),
              State.t(),
              atom(),
              String.t()
            ) :: Phoenix.LiveView.Socket.t()
      def search_relation_options(socket, state, field_name, search_term) do
        field = find_field(state, field_name)

        if field do
          tenant = tenant_resolver().get_tenant(state)
          relation_mod = relation_loader()

          current_opts = Map.get(state.relation_options, field_name, %{})

          relation_options =
            Map.put(state.relation_options, field_name, Map.put(current_opts, :loading?, true))

          state = State.update(state, relation_options: relation_options)

          socket
          |> Phoenix.Component.assign(:form_state, state)
          |> Phoenix.LiveView.start_async(
            {:search_relation, field_name},
            fn ->
              relation_mod.search_options(field, state, search_term, tenant: tenant)
            end
          )
        else
          socket
        end
      end

      @doc """
      Handle async result from record loading.
      """
      @spec handle_async_result(
              atom() | {atom(), atom()},
              {:ok, any()} | {:exit, any()},
              Phoenix.LiveView.Socket.t()
            ) :: Phoenix.LiveView.Socket.t()
      def handle_async_result(:load_record, {:ok, {:ok, form}}, socket) do
        state = socket.assigns.form_state
        form = run_on_init_hook(state, form)
        existing_files = extract_existing_files(state, form)
        field_values = extract_dependency_values(state, form)

        state =
          State.update(state,
            form: form,
            loading: :loaded,
            existing_files: existing_files,
            field_values: field_values
          )

        socket
        |> Phoenix.Component.assign(:form_state, state)
        |> load_dependent_relations(state)
        |> load_readonly_relation_options(state)
      end

      def handle_async_result(:load_record, {:ok, {:error, _reason}}, socket) do
        state = socket.assigns.form_state
        state = State.update(state, loading: :error)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      def handle_async_result(:load_record, {:exit, _reason}, socket) do
        state = socket.assigns.form_state
        state = State.update(state, loading: :error)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      def handle_async_result(
            {:load_relation, field_name},
            {:ok, {:ok, options, has_more?}},
            socket
          ) do
        state = socket.assigns.form_state
        current_opts = Map.get(state.relation_options, field_name, %{})

        relation_options =
          Map.put(
            state.relation_options,
            field_name,
            Map.merge(current_opts, %{
              options: options,
              has_more?: has_more?,
              loading?: false,
              page: 1
            })
          )

        state = State.update(state, relation_options: relation_options)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      def handle_async_result({:load_relation, field_name}, _error, socket) do
        state = socket.assigns.form_state
        current_opts = Map.get(state.relation_options, field_name, %{})

        relation_options =
          Map.put(state.relation_options, field_name, Map.put(current_opts, :loading?, false))

        state = State.update(state, relation_options: relation_options)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      def handle_async_result(
            {:search_relation, field_name},
            {:ok, {:ok, options, has_more?}},
            socket
          ) do
        state = socket.assigns.form_state
        current_opts = Map.get(state.relation_options, field_name, %{})

        relation_options =
          Map.put(
            state.relation_options,
            field_name,
            Map.merge(current_opts, %{
              options: options,
              has_more?: has_more?,
              loading?: false,
              page: 1
            })
          )

        state = State.update(state, relation_options: relation_options)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      def handle_async_result({:search_relation, field_name}, _error, socket) do
        state = socket.assigns.form_state
        current_opts = Map.get(state.relation_options, field_name, %{})

        relation_options =
          Map.put(state.relation_options, field_name, Map.put(current_opts, :loading?, false))

        state = State.update(state, relation_options: relation_options)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      def handle_async_result(_, _, socket), do: socket

      @spec find_field(State.t(), atom()) :: map() | nil
      defp find_field(state, field_name) do
        Enum.find(state.static.fields, &(&1.name == field_name))
      end

      @spec extract_existing_files(State.t(), Phoenix.HTML.Form.t()) :: %{atom() => list(map())}
      defp extract_existing_files(%{static: %{uploads: uploads}}, form)
           when is_list(uploads) and uploads != [] do
        extract_from_record(uploads, form)
      end

      defp extract_existing_files(_state, _form), do: %{}

      defp extract_from_record(uploads, %{source: %{source: %{data: record}}})
           when not is_nil(record) do
        Map.new(uploads, fn upload_config ->
          files = read_existing_files(upload_config, record)
          {upload_config.name, normalize_file_list(files)}
        end)
      end

      defp extract_from_record(_uploads, _form), do: %{}

      defp read_existing_files(upload_config, record) do
        case upload_config[:existing] do
          nil ->
            field = upload_config[:field] || upload_config.name
            Map.get(record, field)

          field_name when is_atom(field_name) ->
            Map.get(record, field_name)

          fun when is_function(fun, 1) ->
            fun.(record)

          _ ->
            nil
        end
      end

      defp normalize_file_list(nil), do: []
      defp normalize_file_list(value) when is_binary(value), do: [%{filename: value}]

      defp normalize_file_list(value) when is_list(value),
        do: Enum.map(value, &normalize_file_info/1)

      defp normalize_file_list(value) when is_map(value), do: [normalize_file_info(value)]
      defp normalize_file_list(_), do: []

      defp normalize_file_info(%{filename: _} = file), do: file
      defp normalize_file_info(%{name: name} = file), do: Map.put(file, :filename, name)

      defp normalize_file_info(%{"filename" => filename} = file),
        do: %{filename: filename, id: file["id"]}

      defp normalize_file_info(%{"name" => name} = file), do: %{filename: name, id: file["id"]}
      defp normalize_file_info(value) when is_binary(value), do: %{filename: value}
      defp normalize_file_info(other), do: %{filename: inspect(other)}

      @spec extract_dependency_values(State.t(), Phoenix.HTML.Form.t()) :: map()
      defp extract_dependency_values(state, form) do
        record =
          case form do
            %{source: %{source: %{data: data}}} when not is_nil(data) -> data
            _ -> nil
          end

        if is_nil(record) do
          %{}
        else
          dependency_names =
            state.static.fields
            |> Enum.map(& &1.depends_on)
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq()

          relation_names =
            state.static.fields
            |> Enum.filter(&(&1.type == :relation))
            |> Enum.map(& &1.name)

          derive_fns =
            state.static.fields
            |> Enum.filter(&(not is_nil(&1[:derive_value])))
            |> Map.new(&{&1.name, &1.derive_value})

          (dependency_names ++ relation_names)
          |> Enum.uniq()
          |> Enum.reduce(%{}, fn field_name, acc ->
            value = Map.get(record, field_name)

            value =
              case value do
                nil ->
                  case Map.get(derive_fns, field_name) do
                    nil -> nil
                    derive_fn -> derive_fn.(record)
                  end

                other ->
                  other
              end

            case value do
              nil -> acc
              "" -> acc
              _ -> Map.put(acc, field_name, value)
            end
          end)
        end
      end

      @spec load_dependent_relations(Phoenix.LiveView.Socket.t(), State.t()) ::
              Phoenix.LiveView.Socket.t()
      defp load_dependent_relations(socket, state) do
        state.static.fields
        |> Enum.filter(fn field ->
          field.depends_on != nil and
            Map.has_key?(state.field_values, field.depends_on) and
            field.type == :relation
        end)
        |> Enum.reduce(socket, fn field, acc ->
          load_relation_options(acc, state, field.name)
        end)
      end

      @spec run_on_init_hook(State.t(), Phoenix.HTML.Form.t()) :: Phoenix.HTML.Form.t()
      defp run_on_init_hook(%{static: %{hooks: %{on_init: on_init}}} = state, form)
           when is_function(on_init, 2) do
        case on_init.(form, state) do
          %Phoenix.HTML.Form{} = modified_form -> modified_form
          _ -> form
        end
      end

      defp run_on_init_hook(_state, form), do: form

      @spec extract_defaults_to_field_values(State.t()) :: map()
      defp extract_defaults_to_field_values(%{defaults: defaults})
           when is_map(defaults) and defaults != %{} do
        defaults
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Map.new()
      end

      defp extract_defaults_to_field_values(_state), do: %{}

      @spec load_readonly_relation_options(Phoenix.LiveView.Socket.t(), State.t()) ::
              Phoenix.LiveView.Socket.t()
      defp load_readonly_relation_options(socket, original_state) do
        relation_mod = relation_loader()

        original_state.static.fields
        |> Enum.filter(fn field ->
          field.type == :relation and
            field_readonly?(field, original_state) and
            Map.has_key?(original_state.field_values, field.name)
        end)
        |> Enum.reduce(socket, fn field, acc ->
          value = Map.get(original_state.field_values, field.name)
          ids = if is_list(value), do: Enum.map(value, &to_string/1), else: [to_string(value)]

          case relation_mod.resolve_selected(field, original_state, ids) do
            {:ok, resolved} when resolved != [] ->
              current_state = acc.assigns.form_state
              current_opts = Map.get(current_state.relation_options, field.name, %{})

              new_opts =
                Map.merge(current_opts, %{
                  options: resolved,
                  selected_options: resolved,
                  loading?: false
                })

              relation_options = Map.put(current_state.relation_options, field.name, new_opts)

              Phoenix.Component.assign(
                acc,
                :form_state,
                State.update(current_state, relation_options: relation_options)
              )

            _ ->
              acc
          end
        end)
      end

      defp field_readonly?(%{readonly: f}, state) when is_function(f, 1), do: f.(state)
      defp field_readonly?(%{readonly: true}, _), do: true
      defp field_readonly?(_, _), do: false

      defoverridable record_loader: 0,
                     tenant_resolver: 0,
                     relation_loader: 0,
                     hook_runner: 0,
                     load_record: 3,
                     new_record: 2,
                     load_relation_options: 3,
                     search_relation_options: 4,
                     handle_async_result: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.DataLoader.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.DataLoader
end
