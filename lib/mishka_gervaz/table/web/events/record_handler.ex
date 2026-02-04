defmodule MishkaGervaz.Table.Web.Events.RecordHandler do
  @moduledoc """
  Handles record operations for Events module.

  This module provides functions for fetching, deleting, unarchiving, and
  permanently destroying records.

  ## Customization

  You can create a custom RecordHandler:

      defmodule MyApp.CustomRecordHandler do
        use MishkaGervaz.Table.Web.Events.RecordHandler

        # Custom delete that adds audit logging
        def delete_record(state, record) do
          result = super(state, record)
          MyApp.AuditLog.log_delete(record, state.current_user)
          result
        end
      end

  Then configure it in your resource's DSL:

      mishka_gervaz do
        table do
          events do
            record MyApp.CustomRecordHandler
          end
        end
      end
  """

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Resource.Info.Table, as: Info

  @type state :: State.t()
  @type record :: struct()
  @type archive_status :: :active | :archived

  @doc """
  Fetches a record by ID.

  Uses the appropriate action based on archive status and user type.
  """
  @callback get_record(state :: state(), id :: String.t(), archive_status :: archive_status()) ::
              record()

  @doc """
  Deletes a record using the source destroy action.

  Returns `{:ok, deleted_record}` or `{:error, reason}`.
  """
  @callback delete_record(state :: state(), record :: record()) ::
              {:ok, record()} | {:error, term()}

  @doc """
  Destroys a record with a specific Ash action.

  The action can be an atom or tuple {master_action, tenant_action}.
  Returns `{:ok, destroyed_record}` or `{:error, reason}`.
  """
  @callback destroy_record(
              state :: state(),
              record :: record(),
              action :: atom() | {atom(), atom()}
            ) ::
              {:ok, record()} | {:error, term()}

  @doc """
  Restores an archived record.

  Returns `{:ok, restored_record}` or `{:error, reason}`.
  """
  @callback unarchive_record(state :: state(), record :: record()) ::
              {:ok, record()} | {:error, term()}

  @doc """
  Permanently destroys an archived record.

  Returns `{:ok, destroyed_record}` or `{:error, reason}`.
  """
  @callback permanent_destroy_record(state :: state(), record :: record()) ::
              {:ok, record()} | {:error, term()}

  @doc """
  Updates a record with a specific Ash action.

  The action can be an atom or tuple {master_action, tenant_action}.
  Returns `{:ok, updated_record}` or `{:error, reason}`.
  """
  @callback update_record(
              state :: state(),
              record :: record(),
              action :: atom() | {atom(), atom()}
            ) ::
              {:ok, record()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.RecordHandler

      alias MishkaGervaz.Table.Web.State
      alias MishkaGervaz.Resource.Info.Table, as: Info

      @impl true
      @spec get_record(State.t(), binary(), :active | :archived) :: struct()
      def get_record(state, id, archive_status) do
        action =
          case archive_status do
            :archived ->
              Info.archive_action_for(state.static.resource, :get, state.master_user?) ||
                Info.action_for(state.static.resource, :get, state.master_user?)

            _ ->
              Info.action_for(state.static.resource, :get, state.master_user?)
          end

        tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)
        opts = [action: action, actor: state.current_user, load: State.get_preloads(state)]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        Ash.get!(state.static.resource, id, opts)
        |> MishkaGervaz.Helpers.inject_preload_aliases(state.preload_aliases)
      end

      @impl true
      @spec delete_record(State.t(), struct()) :: {:ok, struct()} | {:error, term()}
      def delete_record(state, record) do
        action = State.get_action(state, :destroy)
        tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)

        opts = [
          action: action,
          actor: state.current_user,
          return_destroyed?: true
        ]

        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        Ash.destroy(record, opts)
      end

      @impl true
      @spec destroy_record(State.t(), struct(), atom() | {atom(), atom()}) ::
              {:ok, struct()} | {:error, term()}
      def destroy_record(state, record, action_spec) do
        action =
          case action_spec do
            {master_action, tenant_action} ->
              if state.master_user?, do: master_action, else: tenant_action

            action when is_atom(action) ->
              action
          end

        tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)

        opts = [
          action: action,
          actor: state.current_user,
          return_destroyed?: true
        ]

        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        Ash.destroy(record, opts)
      end

      @impl true
      @spec unarchive_record(State.t(), struct()) :: {:ok, struct()} | {:error, term()}
      def unarchive_record(state, record) do
        action =
          Info.archive_action_for(state.static.resource, :restore, state.master_user?) ||
            :unarchive

        tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)

        opts = [
          action: action,
          actor: state.current_user
        ]

        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        Ash.update(record, opts)
      end

      @impl true
      @spec permanent_destroy_record(State.t(), struct()) :: {:ok, struct()} | {:error, term()}
      def permanent_destroy_record(state, record) do
        action =
          Info.archive_action_for(state.static.resource, :destroy, state.master_user?) ||
            :permanent_destroy

        tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)

        opts = [
          action: action,
          actor: state.current_user,
          return_destroyed?: true
        ]

        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        Ash.destroy(record, opts)
      end

      @impl true
      @spec update_record(State.t(), struct(), atom() | {atom(), atom()}) ::
              {:ok, struct()} | {:error, term()}
      def update_record(state, record, action_spec) do
        action =
          case action_spec do
            {master_action, tenant_action} ->
              if state.master_user?, do: master_action, else: tenant_action

            action when is_atom(action) ->
              action
          end

        tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)

        opts = [
          action: action,
          actor: state.current_user
        ]

        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        Ash.update(record, %{}, opts)
      end

      defoverridable get_record: 3,
                     delete_record: 2,
                     destroy_record: 3,
                     unarchive_record: 2,
                     permanent_destroy_record: 2,
                     update_record: 3
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.RecordHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.RecordHandler
end
