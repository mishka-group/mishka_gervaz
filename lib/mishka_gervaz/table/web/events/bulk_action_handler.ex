defmodule MishkaGervaz.Table.Web.Events.BulkActionHandler do
  @moduledoc """
  Handles bulk action execution for Events module.

  This module provides functions for executing bulk actions on selected records,
  including building queries and running Ash bulk operations.

  ## Customization

  You can create a custom BulkActionHandler:

      defmodule MyApp.CustomBulkActionHandler do
        use MishkaGervaz.Table.Web.Events.BulkActionHandler

        # Custom bulk action with additional logging
        def execute_ash_bulk_action(action, ash_action, selected_ids, state, socket) do
          MyApp.Logger.info("Executing bulk action", action: ash_action, count: length(selected_ids))
          super(action, ash_action, selected_ids, state, socket)
        end
      end

  Then configure it in your resource's DSL:

      mishka_gervaz do
        table do
          events do
            bulk_action MyApp.CustomBulkActionHandler
          end
        end
      end
  """

  alias MishkaGervaz.Table.Web.{State, DataLoader}
  alias MishkaGervaz.Errors

  require Ash.Query

  @type state :: State.t()
  @type socket :: Phoenix.LiveView.Socket.t()
  @type bulk_action :: map()
  @type selected_ids :: list() | :all | {:all_except, list()}

  @doc """
  Executes a bulk action based on its handler type.

  Dispatches to the appropriate handler: `:parent`, function, or Ash action.
  """
  @callback execute(
              bulk_action :: bulk_action() | nil,
              selected_ids :: selected_ids(),
              state :: state(),
              socket :: socket()
            ) :: {:noreply, socket()}

  @doc """
  Executes an Ash bulk action.

  Handles both bulk_update and bulk_destroy based on action type.
  """
  @callback execute_ash_bulk_action(
              action :: bulk_action(),
              ash_action :: atom(),
              selected_ids :: selected_ids(),
              state :: state(),
              socket :: socket()
            ) :: {:noreply, socket()}

  @doc """
  Builds a query for bulk operations.

  Applies any necessary filters based on the selection.
  """
  @callback build_bulk_query(
              resource :: module(),
              state :: state(),
              filter :: {:exclude, list()} | nil
            ) :: Ash.Query.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.BulkActionHandler

      alias MishkaGervaz.Table.Web.{State, DataLoader}
      alias MishkaGervaz.Resource.Info.Table, as: Info
      alias MishkaGervaz.Errors

      require Ash.Query

      @spec put_error_flash(Phoenix.LiveView.Socket.t(), Exception.t()) ::
              Phoenix.LiveView.Socket.t()
      defp put_error_flash(socket, error) do
        message = Errors.format_flash_message(error)
        send(self(), {:put_flash, :error, message})
        socket
      end

      @impl true
      @spec execute(
              map() | nil,
              list() | :all | {:all_except, list()},
              State.t(),
              Phoenix.LiveView.Socket.t()
            ) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      def execute(nil, selected_ids, _state, socket) do
        send(self(), {:bulk_action, :unknown, selected_ids})
        {:noreply, socket}
      end

      def execute(%{handler: :parent} = action, selected_ids, _state, socket) do
        send(self(), {:bulk_action, action.name, selected_ids})
        {:noreply, socket}
      end

      def execute(%{handler: :event, event: event_name} = _action, selected_ids, _state, socket) do
        send(self(), {:bulk_action, event_name, selected_ids})
        {:noreply, socket}
      end

      def execute(%{handler: {:type, :event}} = action, selected_ids, _state, socket) do
        event_name = action[:event] || action.name
        send(self(), {:bulk_action, event_name, selected_ids})
        {:noreply, socket}
      end

      def execute(%{handler: {:type, :destroy}} = action, selected_ids, state, socket) do
        ash_action = Info.action_for(state.static.resource, :destroy, state.master_user?)
        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      def execute(
            %{handler: {:type, :update}, action: action_spec} = action,
            selected_ids,
            state,
            socket
          ) do
        ash_action = resolve_action_spec(action_spec, state.master_user?)
        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      def execute(%{handler: {:type, :unarchive}} = action, selected_ids, state, socket) do
        ash_action =
          Info.archive_action_for(state.static.resource, :restore, state.master_user?) ||
            :unarchive

        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      def execute(%{handler: {:type, :permanent_destroy}} = action, selected_ids, state, socket) do
        ash_action =
          Info.archive_action_for(state.static.resource, :destroy, state.master_user?) ||
            :permanent_destroy

        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      def execute(%{handler: handler} = action, selected_ids, state, socket)
          when is_function(handler, 2) do
        case handler.(selected_ids, state) do
          {:ok, %State{} = new_state} ->
            socket = Phoenix.Component.assign(socket, :table_state, new_state)
            {:noreply, socket}

          :reload ->
            socket = DataLoader.load_async(socket, state, page: 1, reset: true)
            {:noreply, socket}

          {:error, reason} ->
            error =
              Errors.Action.Failed.exception(
                resource: state.static.resource,
                action: action.name,
                reason: reason,
                record_id: nil
              )

            {:noreply, put_error_flash(socket, error)}

          :ok ->
            {:noreply, socket}
        end
      end

      def execute(
            %{handler: {master_action, tenant_action}} = action,
            selected_ids,
            state,
            socket
          ) do
        ash_action = if state.master_user?, do: master_action, else: tenant_action
        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      def execute(%{handler: ash_action} = action, selected_ids, state, socket)
          when is_atom(ash_action) do
        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      @impl true
      @spec execute_ash_bulk_action(
              map(),
              atom(),
              list() | :all | {:all_except, list()},
              State.t(),
              Phoenix.LiveView.Socket.t()
            ) :: {:noreply, Phoenix.LiveView.Socket.t()}
      def execute_ash_bulk_action(action, ash_action, selected_ids, state, socket) do
        action_type = get_action_type(state.static.resource, ash_action)
        tenant = if state.current_user, do: Map.get(state.current_user, :site_id), else: nil
        soft_delete? = soft_delete_action?(state.static.resource, ash_action, action_type)

        opts = [
          action: ash_action,
          actor: state.current_user,
          notify?: true
        ]

        opts = Keyword.put(opts, :return_records?, true)

        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        effective_type = if soft_delete?, do: :soft_delete, else: action_type

        result =
          run_ash_bulk_action(state.static.resource, selected_ids, opts, state, effective_type)

        case result do
          %Ash.BulkResult{status: :success} ->
            state =
              State.update(state,
                selected_ids: MapSet.new(),
                excluded_ids: MapSet.new(),
                select_all?: false
              )

            socket = DataLoader.load_async(socket, state, page: 1, reset: true)
            {:noreply, socket}

          %Ash.BulkResult{status: status, errors: errors} ->
            error =
              Errors.Action.Failed.exception(
                resource: state.static.resource,
                action: action.name,
                reason: {:bulk_action_failed, status, errors},
                record_id: nil
              )

            {:noreply, put_error_flash(socket, error)}
        end
      end

      @impl true
      @spec build_bulk_query(module(), State.t(), {:exclude, list()} | nil) :: Ash.Query.t()
      def build_bulk_query(resource, state, filter) do
        action =
          if state.archive_status == :archived do
            Info.archive_action_for(resource, :read, state.master_user?)
          else
            Info.action_for(resource, :read, state.master_user?)
          end

        tenant =
          if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)

        read_opts = [actor: state.current_user]
        read_opts = if tenant, do: Keyword.put(read_opts, :tenant, tenant), else: read_opts

        query = Ash.Query.for_read(resource, action, %{}, read_opts)

        case filter do
          {:exclude, excluded_ids} ->
            Ash.Query.filter_input(query, %{not: %{id: %{in: excluded_ids}}})

          _ ->
            query
        end
      end

      @spec resolve_action_spec({atom(), atom()} | atom() | nil, boolean()) :: atom()
      defp resolve_action_spec({master_action, tenant_action}, master_user?) do
        if master_user?, do: master_action, else: tenant_action
      end

      defp resolve_action_spec(action, _master_user?) when is_atom(action), do: action
      defp resolve_action_spec(nil, _master_user?), do: :update

      @spec get_action_type(module(), atom()) :: atom()
      defp get_action_type(resource, action_name) do
        case Ash.Resource.Info.action(resource, action_name) do
          %{type: type} -> type
          _ -> :update
        end
      end

      @spec soft_delete_action?(module(), atom(), atom()) :: boolean()
      defp soft_delete_action?(resource, action_name, :destroy) do
        case Ash.Resource.Info.action(resource, action_name) do
          %{soft?: true} -> true
          _ -> false
        end
      end

      defp soft_delete_action?(_resource, _action_name, _action_type), do: false

      @spec run_ash_bulk_action(
              module(),
              :all | {:all_except, list()} | list(),
              keyword(),
              State.t(),
              atom()
            ) :: Ash.BulkResult.t()
      defp run_ash_bulk_action(resource, :all, opts, state, action_type) do
        query = build_bulk_query(resource, state, nil)
        execute_bulk_by_type(query, opts, action_type)
      end

      defp run_ash_bulk_action(resource, {:all_except, excluded_ids}, opts, state, action_type) do
        query = build_bulk_query(resource, state, {:exclude, excluded_ids})
        execute_bulk_by_type(query, opts, action_type)
      end

      defp run_ash_bulk_action(resource, ids, opts, state, action_type) when is_list(ids) do
        query =
          build_bulk_query(resource, state, nil)
          |> Ash.Query.filter_input(%{id: %{in: ids}})

        execute_bulk_by_type(query, opts, action_type)
      end

      @spec execute_bulk_by_type(Ash.Query.t(), keyword(), atom()) :: Ash.BulkResult.t()
      defp execute_bulk_by_type(query, opts, :destroy) do
        {action, opts} = Keyword.pop!(opts, :action)
        opts = Keyword.put_new(opts, :strategy, [:atomic, :atomic_batches, :stream])
        opts = Keyword.put_new(opts, :allow_stream_with, :full_read)
        Ash.bulk_destroy(query, action, %{}, opts)
      end

      defp execute_bulk_by_type(query, opts, :soft_delete) do
        {action, opts} = Keyword.pop!(opts, :action)
        opts = Keyword.put_new(opts, :strategy, [:atomic, :atomic_batches, :stream])
        opts = Keyword.put_new(opts, :allow_stream_with, :full_read)
        Ash.bulk_update(query, action, %{}, opts)
      end

      defp execute_bulk_by_type(query, opts, _action_type) do
        {action, opts} = Keyword.pop!(opts, :action)
        opts = Keyword.put_new(opts, :strategy, [:atomic, :atomic_batches, :stream])
        opts = Keyword.put_new(opts, :allow_stream_with, :full_read)
        Ash.bulk_update(query, action, %{}, opts)
      end

      defoverridable execute: 4,
                     execute_ash_bulk_action: 5,
                     build_bulk_query: 3
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.BulkActionHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.BulkActionHandler
end
