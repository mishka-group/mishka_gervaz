defmodule MishkaGervaz.Table.Web.Events.BulkActionHandler do
  @moduledoc """
  Handles bulk action execution for Events module.

  Runs Ash bulk operations on the selection, classifies the outcome, and
  routes through the lifecycle hooks before falling back to a sensible
  default flash.

  ## Lifecycle (Ash bulk paths)

  Per bulk action:

    1. `:after_bulk_action` runs with `(summary, state)` regardless of outcome.
    2. Branch on `summary.status`:
       - `:success` — `:on_bulk_action_success` runs; **no default flash**
         (the table reload is the user-visible feedback).
       - `:partial_success` — `:on_bulk_action_success` runs first; if the
         hook returns the socket, a default info flash fires
         (`"X succeeded, Y failed."`). Hooks return `{:halt, socket}` to
         suppress the default.
       - `:error` — `:on_bulk_action_error` runs first; same override
         semantics, defaulting to the formatted error flash. The selection
         is preserved so the user can retry.
    3. For the unarchive partial-skip path (rows whose identity is already
       taken by an active row), `:on_bulk_action_success` runs with a
       summary whose `:skipped_count` / `:skipped_record_ids` describe the
       skipped rows; default flash is `"X unarchived, Y skipped — a record
       with the same name already exists."`. Skipped rows stay selected.

  See `MishkaGervaz.Table.Web.Events.BulkActionResult` for the summary
  shape; `MishkaGervaz.Table.Web.Events.BulkActionHooks` for `silence/1`
  and `use_default/1`.

  ## Customization

  Two layers of customization:

  **1. Replace the handler module** for full control:

      defmodule MyApp.CustomBulkActionHandler do
        use MishkaGervaz.Table.Web.Events.BulkActionHandler

        def execute_ash_bulk_action(action, ash_action, selected_ids, state, socket) do
          MyApp.Logger.info("bulk", action: ash_action, count: length(selected_ids))
          super(action, ash_action, selected_ids, state, socket)
        end
      end

  Wired in the DSL:

      mishka_gervaz do
        table do
          events do
            bulk_action MyApp.CustomBulkActionHandler
          end
        end
      end

  **2. Just adjust messaging** via per-action hooks (most common):

      hooks do
        on_bulk_action_success :master_destroy, fn summary, _state, socket ->
          socket
          |> Phoenix.LiveView.put_flash(:info, "\#{summary.succeeded_count} deleted.")
          |> MishkaGervaz.Table.Web.Events.BulkActionHooks.silence()
        end

        on_bulk_action_error :master_destroy, fn summary, _state, socket ->
          Logger.error("delete failed: \#{inspect(summary.failed_errors)}")
          MishkaGervaz.Table.Web.Events.BulkActionHooks.silence(socket)
        end
      end

  See `MishkaGervaz.Table.Web.Events`,
  `MishkaGervaz.Table.Entities.BulkAction`,
  `MishkaGervaz.Table.Web.DataLoader`,
  `MishkaGervaz.Table.Web.Events.BulkActionResult`,
  `MishkaGervaz.Table.Web.Events.BulkActionHooks`,
  and the sibling handlers `SanitizationHandler`, `RecordHandler`,
  `SelectionHandler`, `HookRunner`, `RelationFilterHandler`.
  """

  alias MishkaGervaz.Table.Web.{State, DataLoader}
  alias MishkaGervaz.Table.Web.Events.BulkActionResult
  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Errors

  @doc false
  @spec put_error_flash(Phoenix.LiveView.Socket.t(), Exception.t()) ::
          Phoenix.LiveView.Socket.t()
  def put_error_flash(socket, error) do
    message = Errors.format_flash_message(error)
    send(self(), {:put_flash, :error, message})
    socket
  end

  @doc false
  @spec hook_runner_for(State.t()) :: module()
  def hook_runner_for(state) do
    case Info.events(state.static.resource) do
      %{hooks: mod} when is_atom(mod) and not is_nil(mod) -> mod
      _ -> MishkaGervaz.Table.Web.Events.HookRunner.Default
    end
  end

  @doc false
  @spec run_lifecycle_hook(State.t(), atom(), map() | nil, list()) :: any()
  def run_lifecycle_hook(_state, _phase, nil, _args), do: nil

  def run_lifecycle_hook(state, phase, %{name: action_name}, args) do
    hooks = state.static.hooks
    runner = hook_runner_for(state)
    runner.run_hook(hooks, {phase, action_name}, args)
  end

  @doc false
  @spec apply_lifecycle_socket(
          State.t(),
          atom(),
          map() | nil,
          list(),
          Phoenix.LiveView.Socket.t()
        ) :: Phoenix.LiveView.Socket.t()
  def apply_lifecycle_socket(state, phase, action, args, socket) do
    apply_lifecycle_with_default(state, phase, action, args, socket, & &1)
  end

  @doc false
  @spec adapt_lifecycle_args(
          map() | nil,
          {atom(), atom()},
          list(),
          Phoenix.LiveView.Socket.t()
        ) :: list()
  def adapt_lifecycle_args(hooks, hook_key, args, socket) when is_map(hooks) do
    case Map.get(hooks, hook_key) do
      fun when is_function(fun, 3) -> args ++ [socket]
      _ -> args
    end
  end

  def adapt_lifecycle_args(_hooks, _hook_key, args, _socket), do: args

  @doc false
  @spec builtin_enabled?(State.t(), atom()) :: boolean()
  def builtin_enabled?(state, key) do
    case state.static.hooks do
      %{__builtins__: %{} = b} -> Map.get(b, key) == true
      _ -> key == :clear_selection_after_bulk
    end
  end

  @doc false
  @spec resolve_action_spec({atom(), atom()} | atom() | nil, boolean()) :: atom()
  def resolve_action_spec({master_action, tenant_action}, master_user?) do
    if master_user?, do: master_action, else: tenant_action
  end

  def resolve_action_spec(nil, _master_user?), do: :update
  def resolve_action_spec(action, _master_user?) when is_atom(action), do: action

  @doc false
  @spec get_action_type(module(), atom()) :: atom()
  def get_action_type(resource, action_name) do
    case Ash.Resource.Info.action(resource, action_name) do
      %{type: type} -> type
      _ -> :update
    end
  end

  @doc false
  @spec soft_delete_action?(module(), atom(), atom()) :: boolean()
  def soft_delete_action?(resource, action_name, :destroy) do
    case Ash.Resource.Info.action(resource, action_name) do
      %{soft?: true} -> true
      _ -> false
    end
  end

  def soft_delete_action?(_resource, _action_name, _action_type), do: false

  @doc false
  @spec build_ash_bulk_opts(State.t(), atom()) :: {keyword(), atom()}
  def build_ash_bulk_opts(state, ash_action) do
    action_type = get_action_type(state.static.resource, ash_action)

    effective_type =
      if soft_delete_action?(state.static.resource, ash_action, action_type),
        do: :soft_delete,
        else: action_type

    tenant = if state.current_user, do: Map.get(state.current_user, :site_id), else: nil

    opts =
      [action: ash_action, actor: state.current_user, notify?: true, return_records?: true]
      |> then(fn list -> if tenant, do: Keyword.put(list, :tenant, tenant), else: list end)

    {opts, effective_type}
  end

  @doc false
  @spec build_read_opts(State.t()) :: keyword()
  def build_read_opts(state) do
    tenant = if state.master_user?, do: nil, else: Map.get(state.current_user, :site_id)
    opts = [actor: state.current_user]
    if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts
  end

  @doc false
  @spec apply_lifecycle_with_default(
          State.t(),
          atom(),
          map() | nil,
          list(),
          Phoenix.LiveView.Socket.t(),
          (Phoenix.LiveView.Socket.t() -> Phoenix.LiveView.Socket.t())
        ) :: Phoenix.LiveView.Socket.t()
  def apply_lifecycle_with_default(_state, _phase, nil, _args, socket, _default_fun), do: socket

  def apply_lifecycle_with_default(state, phase, %{name: action_name}, args, socket, default_fun) do
    hooks = state.static.hooks
    runner = hook_runner_for(state)
    full_args = adapt_lifecycle_args(hooks, {phase, action_name}, args, socket)

    case runner.apply_hook_result(hooks, {phase, action_name}, full_args, socket) do
      {:halt, sock} -> sock
      sock -> default_fun.(sock)
    end
  end

  @doc false
  @spec execute_bulk_by_type(Ash.Query.t(), keyword(), atom()) :: Ash.BulkResult.t()
  def execute_bulk_by_type(query, opts, :destroy) do
    {action, opts} = pop_action_and_defaults(opts)
    Ash.bulk_destroy(query, action, %{}, opts)
  end

  def execute_bulk_by_type(query, opts, _action_type) do
    {action, opts} = pop_action_and_defaults(opts)
    Ash.bulk_update(query, action, %{}, opts)
  end

  defp pop_action_and_defaults(opts) do
    {action, opts} = Keyword.pop!(opts, :action)

    opts =
      opts
      |> Keyword.put_new(:strategy, [:atomic, :atomic_batches, :stream])
      |> Keyword.put_new(:allow_stream_with, :full_read)

    {action, opts}
  end

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

      import MishkaGervaz.Table.Web.Events.BulkActionHandler,
        only: [
          put_error_flash: 2,
          run_lifecycle_hook: 4,
          apply_lifecycle_socket: 5,
          apply_lifecycle_with_default: 6,
          builtin_enabled?: 2,
          resolve_action_spec: 2,
          get_action_type: 2,
          soft_delete_action?: 3,
          execute_bulk_by_type: 3,
          build_ash_bulk_opts: 2,
          build_read_opts: 1
        ]

      alias MishkaGervaz.Table.Web.Events.BulkActionResult

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

        case unarchive_conflict_ids(state, selected_ids) do
          [] ->
            execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)

          conflict_ids ->
            action
            |> unarchive_skipping_conflicts(ash_action, selected_ids, conflict_ids, state, socket)
        end
      end

      def execute(%{handler: {:type, :permanent_destroy}} = action, selected_ids, state, socket) do
        ash_action =
          Info.archive_action_for(state.static.resource, :destroy, state.master_user?) ||
            :permanent_destroy

        execute_ash_bulk_action(action, ash_action, selected_ids, state, socket)
      end

      def execute(%{handler: handler} = action, selected_ids, state, socket)
          when is_function(handler, 2) do
        result = handler.(selected_ids, state)
        run_lifecycle_hook(state, :after_bulk_action, action, [result, state])

        case result do
          {:ok, %State{} = new_state} ->
            socket = Phoenix.Component.assign(socket, :table_state, new_state)

            socket =
              apply_lifecycle_socket(
                state,
                :on_bulk_action_success,
                action,
                [new_state, state],
                socket
              )

            {:noreply, socket}

          :reload ->
            socket = DataLoader.load_async(socket, state, page: 1, reset: true)

            socket =
              apply_lifecycle_socket(
                state,
                :on_bulk_action_success,
                action,
                [:reload, state],
                socket
              )

            {:noreply, socket}

          {:error, reason} ->
            error =
              Errors.Action.Failed.exception(
                resource: state.static.resource,
                action: action.name,
                reason: reason,
                record_id: nil
              )

            socket = put_error_flash(socket, error)

            socket =
              apply_lifecycle_socket(
                state,
                :on_bulk_action_error,
                action,
                [reason, state],
                socket
              )

            {:noreply, socket}

          :ok ->
            socket =
              apply_lifecycle_socket(
                state,
                :on_bulk_action_success,
                action,
                [:ok, state],
                socket
              )

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
        {opts, effective_type} = build_ash_bulk_opts(state, ash_action)
        requested = if is_list(selected_ids), do: length(selected_ids), else: nil

        result =
          run_ash_bulk_action(state.static.resource, selected_ids, opts, state, effective_type)

        summary =
          BulkActionResult.build(action.name, effective_type, result, requested_count: requested)

        run_lifecycle_hook(state, :after_bulk_action, action, [summary, state])

        case summary.status do
          :success -> finish_bulk_success(action, summary, state, socket)
          :partial_success -> finish_bulk_partial(action, summary, state, socket)
          :error -> finish_bulk_error(action, summary, state, socket)
        end
      end

      defp finish_bulk_success(action, %BulkActionResult{} = summary, state, socket) do
        state
        |> apply_lifecycle_socket(:on_bulk_action_success, action, [summary, state], socket)
        |> reload_after_bulk(action, state)
      end

      defp finish_bulk_partial(action, %BulkActionResult{} = summary, state, socket) do
        state
        |> apply_lifecycle_with_default(
          :on_bulk_action_success,
          action,
          [summary, state],
          socket,
          &default_partial_flash(&1, summary)
        )
        |> reload_after_bulk(action, state)
      end

      defp reload_after_bulk(socket, action, state) do
        new_state =
          if builtin_enabled?(state, :clear_selection_after_bulk) do
            State.update(state,
              selected_ids: MapSet.new(),
              excluded_ids: MapSet.new(),
              select_all?: false
            )
          else
            state
          end

        socket = DataLoader.load_async(socket, new_state, page: 1, reset: true, sync_url: false)
        socket = MishkaGervaz.Table.Web.AutoState.after_bulk_action(socket, new_state, action)
        {:noreply, socket}
      end

      defp finish_bulk_error(action, %BulkActionResult{} = summary, state, socket) do
        socket =
          apply_lifecycle_with_default(
            state,
            :on_bulk_action_error,
            action,
            [summary, state],
            socket,
            &default_error_flash(&1, action, state, summary)
          )

        {:noreply, socket}
      end

      defp default_partial_flash(socket, %BulkActionResult{} = summary) do
        msg = "#{summary.succeeded_count} succeeded, #{summary.failed_count} failed."
        send(self(), {:put_flash, :info, msg})
        socket
      end

      defp default_error_flash(socket, action, state, %BulkActionResult{} = summary) do
        error =
          Errors.Action.Failed.exception(
            resource: state.static.resource,
            action: action.name,
            reason: {:bulk_action_failed, summary.status, summary.failed_errors},
            record_id: nil
          )

        put_error_flash(socket, error)
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

        query = Ash.Query.for_read(resource, action, %{}, build_read_opts(state))

        case filter do
          {:exclude, excluded_ids} ->
            Ash.Query.filter_input(query, %{not: %{id: %{in: excluded_ids}}})

          _ ->
            query
        end
      end

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

      defp unarchive_skipping_conflicts(
             action,
             ash_action,
             selected_ids,
             conflict_ids,
             state,
             socket
           ) do
        resource = state.static.resource
        safe = drop_conflicts(selected_ids, conflict_ids)
        {opts, effective_type} = build_ash_bulk_opts(state, ash_action)
        requested = if is_list(selected_ids), do: length(selected_ids), else: nil

        result = run_ash_bulk_action(resource, safe, opts, state, effective_type)

        summary =
          BulkActionResult.build(action.name, effective_type, result,
            requested_count: requested,
            skipped_record_ids: conflict_ids
          )

        run_lifecycle_hook(state, :after_bulk_action, action, [summary, state])

        case summary.status do
          status when status in [:success, :partial_success] ->
            finish_unarchive_skip(action, summary, conflict_ids, state, socket)

          :error ->
            finish_bulk_error(action, summary, state, socket)
        end
      end

      defp finish_unarchive_skip(
             action,
             %BulkActionResult{} = summary,
             conflict_ids,
             state,
             socket
           ) do
        socket =
          apply_lifecycle_with_default(
            state,
            :on_bulk_action_success,
            action,
            [summary, state],
            socket,
            &default_unarchive_skip_flash(&1, summary)
          )

        new_state =
          State.update(state,
            selected_ids: MapSet.new(conflict_ids),
            excluded_ids: MapSet.new(),
            select_all?: false
          )

        socket = DataLoader.load_async(socket, new_state, page: 1, reset: true, sync_url: false)
        {:noreply, socket}
      end

      defp default_unarchive_skip_flash(socket, %BulkActionResult{} = summary) do
        base =
          "#{summary.succeeded_count} unarchived, #{summary.skipped_count} skipped — " <>
            "a record with the same name already exists."

        msg =
          if summary.status == :partial_success,
            do: base <> " Some operations failed; check logs.",
            else: base

        send(self(), {:put_flash, :info, msg})
        socket
      end

      defp drop_conflicts(ids, conflict_ids) when is_list(ids), do: ids -- conflict_ids
      defp drop_conflicts(:all, conflict_ids), do: {:all_except, conflict_ids}

      defp drop_conflicts({:all_except, excluded}, conflict_ids),
        do: {:all_except, Enum.uniq(excluded ++ conflict_ids)}

      defp unarchive_conflict_ids(state, selected_ids) do
        identities =
          state.static.resource
          |> Ash.Resource.Info.identities()
          |> Enum.reject(&(&1.keys == [:id]))

        with [_ | _] <- identities,
             {:ok, records} <- load_archived_for_conflict_check(state, selected_ids) do
          claimed =
            Map.new(identities, fn identity ->
              {identity.name, active_identity_values(state, identity, records)}
            end)

          {conflicts, _claimed} =
            Enum.reduce(records, {[], claimed}, fn record, {conflicts, claimed} ->
              if identity_taken?(identities, record, claimed) do
                {[record.id | conflicts], claimed}
              else
                {conflicts, claim_identities(identities, record, claimed)}
              end
            end)

          conflicts
        else
          _ -> []
        end
      end

      defp identity_taken?(identities, record, claimed) do
        Enum.any?(identities, fn identity ->
          values = Enum.map(identity.keys, &Map.get(record, &1))
          MapSet.member?(Map.fetch!(claimed, identity.name), values)
        end)
      end

      defp claim_identities(identities, record, claimed) do
        Enum.reduce(identities, claimed, fn identity, acc ->
          values = Enum.map(identity.keys, &Map.get(record, &1))
          Map.update!(acc, identity.name, &MapSet.put(&1, values))
        end)
      end

      defp load_archived_for_conflict_check(state, selected_ids) do
        resource = state.static.resource

        query =
          case selected_ids do
            ids when is_list(ids) ->
              build_bulk_query(resource, state, nil) |> Ash.Query.filter_input(%{id: %{in: ids}})

            {:all_except, excluded} ->
              build_bulk_query(resource, state, {:exclude, excluded})

            :all ->
              build_bulk_query(resource, state, nil)
          end

        read_all(query, build_read_opts(state))
      end

      defp active_identity_values(state, identity, records) do
        resource = state.static.resource
        [first | _] = identity.keys
        values = records |> Enum.map(&Map.get(&1, first)) |> Enum.reject(&is_nil/1) |> Enum.uniq()

        if values == [] do
          MapSet.new()
        else
          read_action = Info.action_for(resource, :read, state.master_user?)
          opts = build_read_opts(state)

          query =
            resource
            |> Ash.Query.for_read(read_action, %{}, opts)
            |> Ash.Query.filter_input(%{first => %{in: values}})

          case read_all(query, opts) do
            {:ok, active} -> identity_value_set(active, identity)
            _ -> MapSet.new()
          end
        end
      end

      defp read_all(query, opts, offset \\ 0, acc \\ []) do
        case Ash.read(query, Keyword.put(opts, :page, limit: 100, offset: offset)) do
          {:ok, %{results: results}} when length(results) == 100 ->
            read_all(query, opts, offset + 100, acc ++ results)

          {:ok, %{results: results}} ->
            {:ok, acc ++ results}

          {:ok, results} when is_list(results) ->
            {:ok, acc ++ results}

          other ->
            if acc == [], do: other, else: {:ok, acc}
        end
      end

      defp identity_value_set(records, identity) do
        MapSet.new(records, fn record -> Enum.map(identity.keys, &Map.get(record, &1)) end)
      end

      defoverridable execute: 4, execute_ash_bulk_action: 5, build_bulk_query: 3
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.BulkActionHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.BulkActionHandler
end
