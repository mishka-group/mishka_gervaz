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
      alias MishkaGervaz.Form.Web.DataLoader.Helpers, as: DataLoaderHelpers
      alias MishkaGervaz.Resource.Info.Form, as: Info

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
        tenant = resolve_tenant_resolver(state.static.resource).get_tenant(state)
        actor = state.current_user
        record_mod = resolve_record_loader(state.static.resource)

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
        tenant = resolve_tenant_resolver(state.static.resource).get_tenant(state)
        actor = state.current_user
        record_mod = resolve_record_loader(state.static.resource)

        case record_mod.new_for_create(state, tenant: tenant, actor: actor) do
          {:ok, form} ->
            form = DataLoaderHelpers.run_on_init_hook(state, form)
            field_values = DataLoaderHelpers.extract_defaults_to_field_values(state)

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
        field = DataLoaderHelpers.find_field(state, field_name)

        if field do
          tenant = resolve_tenant_resolver(state.static.resource).get_tenant(state)
          relation_mod = resolve_relation_loader(state.static.resource)

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
        field = DataLoaderHelpers.find_field(state, field_name)

        if field do
          tenant = resolve_tenant_resolver(state.static.resource).get_tenant(state)
          relation_mod = resolve_relation_loader(state.static.resource)

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
        form = DataLoaderHelpers.run_on_init_hook(state, form)
        existing_files = DataLoaderHelpers.extract_existing_files(state, form)
        field_values = DataLoaderHelpers.extract_dependency_values(state, form)

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

      defp load_dependent_relations(socket, state) do
        DataLoaderHelpers.load_dependent_relations(socket, state, &load_relation_options/3)
      end

      defp load_readonly_relation_options(socket, state) do
        relation_mod = resolve_relation_loader(state.static.resource)
        DataLoaderHelpers.load_readonly_relation_options(socket, state, relation_mod)
      end

      @spec resolve_record_loader(module() | nil) :: module()
      defp resolve_record_loader(nil), do: record_loader()

      defp resolve_record_loader(resource) do
        Map.get(Info.data_loader(resource), :record, record_loader())
      end

      @spec resolve_tenant_resolver(module() | nil) :: module()
      defp resolve_tenant_resolver(nil), do: tenant_resolver()

      defp resolve_tenant_resolver(resource) do
        Map.get(Info.data_loader(resource), :tenant, tenant_resolver())
      end

      @spec resolve_relation_loader(module() | nil) :: module()
      defp resolve_relation_loader(nil), do: relation_loader()

      defp resolve_relation_loader(resource) do
        Map.get(Info.data_loader(resource), :relation, relation_loader())
      end

      @spec resolve_hook_runner(module() | nil) :: module()
      defp resolve_hook_runner(nil), do: hook_runner()

      defp resolve_hook_runner(resource) do
        Map.get(Info.data_loader(resource), :hooks, hook_runner())
      end

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
