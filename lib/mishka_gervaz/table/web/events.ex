defmodule MishkaGervaz.Table.Web.Events do
  @moduledoc """
  Handles all table events for MishkaGervaz.

  This module centralizes event handling for:
  - Sorting
  - Filtering
  - Row actions (delete, edit, custom events)
  - Bulk actions
  - Row expansion
  - Archive status changes
  - Pagination

  ## Sub-builders

  Events functionality is split into specialized sub-builders:

  - `SanitizationHandler` - Input sanitization
  - `RecordHandler` - Record CRUD operations
  - `SelectionHandler` - Selection state management
  - `BulkActionHandler` - Bulk action execution
  - `HookRunner` - Hook execution
  - `RelationFilterHandler` - Relation filter search/select events

  ## Customization

  You can override individual sub-builders via DSL:

      mishka_gervaz do
        table do
          events do
            sanitization MyApp.CustomSanitizationHandler
            record MyApp.CustomRecordHandler
            selection MyApp.CustomSelectionHandler
            bulk_action MyApp.CustomBulkActionHandler
            hooks MyApp.CustomHookRunner
            relation_filter MyApp.CustomRelationFilterHandler
          end
        end
      end

  Or override the entire Events module:

      mishka_gervaz do
        table do
          events MyApp.CustomEvents
        end
      end
  """

  alias MishkaGervaz.Table.Web.{State, DataLoader}

  alias MishkaGervaz.Table.Web.Events.{
    SanitizationHandler,
    RecordHandler,
    SelectionHandler,
    BulkActionHandler,
    HookRunner,
    RelationFilterHandler
  }

  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Errors

  require Ash.Query

  @type socket :: Phoenix.LiveView.Socket.t()
  @type state :: State.t()

  @doc """
  Main event handler dispatcher.

  Called from LiveComponent's handle_event callback.
  """
  @callback handle(event :: String.t(), params :: map(), socket :: socket()) ::
              {:noreply, socket()}

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events

      alias MishkaGervaz.Table.Web.{State, DataLoader}

      alias MishkaGervaz.Table.Web.Events.{
        SanitizationHandler,
        RecordHandler,
        SelectionHandler,
        BulkActionHandler,
        HookRunner,
        RelationFilterHandler
      }

      alias MishkaGervaz.Resource.Info.Table, as: Info
      alias MishkaGervaz.Resource.Info.Form, as: FormInfo
      alias MishkaGervaz.Errors

      require Ash.Query

      @spec sanitization_handler(State.t()) :: module()
      defp sanitization_handler(state) do
        get_events_config(state, :sanitization) ||
          SanitizationHandler.Default
      end

      @spec record_handler(State.t()) :: module()
      defp record_handler(state) do
        get_events_config(state, :record) || RecordHandler.Default
      end

      @spec selection_handler(State.t()) :: module()
      defp selection_handler(state) do
        get_events_config(state, :selection) || SelectionHandler.Default
      end

      @spec bulk_action_handler(State.t()) :: module()
      defp bulk_action_handler(state) do
        get_events_config(state, :bulk_action) || BulkActionHandler.Default
      end

      @spec hook_runner(State.t()) :: module()
      defp hook_runner(state) do
        get_events_config(state, :hooks) || HookRunner.Default
      end

      @spec relation_filter_handler(State.t()) :: module()
      defp relation_filter_handler(state) do
        get_events_config(state, :relation_filter) || RelationFilterHandler.Default
      end

      @spec get_events_config(State.t(), atom()) :: module() | nil
      defp get_events_config(state, key) do
        case Info.events(state.static.resource) do
          config when is_map(config) -> Map.get(config, key)
          _ -> nil
        end
      end

      @spec sanitize(State.t(), any()) :: any()
      defp sanitize(state, value), do: sanitization_handler(state).sanitize(value)

      @spec sanitize_column(State.t(), String.t()) :: atom()
      defp sanitize_column(state, column), do: sanitization_handler(state).sanitize_column(column)

      @spec sanitize_page(State.t(), String.t() | integer()) :: pos_integer()
      defp sanitize_page(state, page), do: sanitization_handler(state).sanitize_page(page)

      @spec get_record(State.t(), String.t(), :active | :archived) :: map() | nil
      defp get_record(state, id, archive_status) do
        record_handler(state).get_record(state, id, archive_status)
      end

      @spec delete_record(State.t(), map()) :: {:ok, map()} | {:error, any()}
      defp delete_record(state, record) do
        record_handler(state).delete_record(state, record)
      end

      @spec destroy_record(State.t(), map(), atom()) :: {:ok, map()} | {:error, any()}
      defp destroy_record(state, record, action) do
        record_handler(state).destroy_record(state, record, action)
      end

      @spec unarchive_record(State.t(), map()) :: {:ok, map()} | {:error, any()}
      defp unarchive_record(state, record) do
        record_handler(state).unarchive_record(state, record)
      end

      @spec permanent_destroy_record(State.t(), map()) :: {:ok, map()} | {:error, any()}
      defp permanent_destroy_record(state, record) do
        record_handler(state).permanent_destroy_record(state, record)
      end

      @spec update_record(State.t(), map(), atom()) :: {:ok, map()} | {:error, any()}
      defp update_record(state, record, action) do
        record_handler(state).update_record(state, record, action)
      end

      @spec toggle_select(State.t(), String.t()) :: State.t()
      defp toggle_select(state, id) do
        selection_handler(state).toggle_select(state, id)
      end

      @spec toggle_select_all(State.t()) :: State.t()
      defp toggle_select_all(state) do
        selection_handler(state).toggle_select_all(state)
      end

      @spec clear_selection(State.t()) :: State.t()
      defp clear_selection(state) do
        selection_handler(state).clear_selection(state)
      end

      @spec get_selected_ids(State.t()) :: MapSet.t()
      defp get_selected_ids(state) do
        selection_handler(state).get_selected_ids(state)
      end

      @spec execute_bulk_action(map() | nil, MapSet.t(), State.t(), Phoenix.LiveView.Socket.t()) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      defp execute_bulk_action(bulk_action, selected_ids, state, socket) do
        bulk_action_handler(state).execute(bulk_action, selected_ids, state, socket)
      end

      @spec run_hook(State.t(), atom() | tuple(), list()) :: any()
      defp run_hook(state, hook_name, args) do
        hook_runner(state).run_hook(state.static.hooks, hook_name, args)
      end

      @spec apply_hook_result(State.t(), atom() | tuple(), list(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t() | {:halt, Phoenix.LiveView.Socket.t()}
      defp apply_hook_result(state, hook_name, args, default_socket) do
        hook_runner(state).apply_hook_result(state.static.hooks, hook_name, args, default_socket)
      end

      @spec run_action_hook(State.t(), atom(), atom(), list()) :: any()
      defp run_action_hook(state, phase, action_name, args) do
        run_hook(state, {phase, action_name}, args)
      end

      @spec apply_action_hook_socket(
              State.t(),
              atom(),
              atom(),
              list(),
              Phoenix.LiveView.Socket.t()
            ) :: Phoenix.LiveView.Socket.t()
      defp apply_action_hook_socket(state, phase, action_name, args, default_socket) do
        case apply_hook_result(state, {phase, action_name}, args, default_socket) do
          {:halt, socket} -> socket
          socket -> socket
        end
      end

      @spec halted_before_action?(State.t(), atom(), atom(), list()) :: boolean()
      defp halted_before_action?(state, phase, action_name, args) do
        case run_action_hook(state, phase, action_name, args) do
          {:halt, _} -> true
          _ -> false
        end
      end

      @spec put_error_flash(Phoenix.LiveView.Socket.t(), any()) :: Phoenix.LiveView.Socket.t()
      defp put_error_flash(socket, error) do
        message = Errors.format_flash_message(error)
        send(self(), {:put_flash, :error, message})
        socket
      end

      @impl true
      def handle(event, params, socket) do
        state = socket.assigns.table_state
        do_handle(event, params, state, socket)
      end

      @spec do_handle(String.t(), map(), State.t(), Phoenix.LiveView.Socket.t()) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      defp do_handle("sort", %{"column" => column}, state, socket) do
        field_atom = sanitize_column(state, column)
        socket = DataLoader.apply_sort(socket, state, field_atom)

        updated_state = socket.assigns.table_state
        sort_info = List.first(updated_state.sort_fields)
        socket = apply_hook_result(state, :on_sort, [sort_info, socket], socket)

        {:noreply, socket}
      end

      defp do_handle("filter", %{"_target" => ["reset"]} = _params, state, socket) do
        socket =
          %{State.update(state, filter_values: %{}) | relation_filter_state: %{}}
          |> then(&DataLoader.load_async(socket, &1, page: 1, reset: true))

        {:noreply, socket}
      end

      defp do_handle("filter", params, state, socket) do
        filter_values =
          state.static.filters
          |> Enum.reduce(%{}, fn filter, acc ->
            field_name = to_string(filter.name)

            value =
              case filter.type do
                :date_range ->
                  from_val = sanitize(state, Map.get(params, "#{field_name}_from", ""))
                  to_val = sanitize(state, Map.get(params, "#{field_name}_to", ""))

                  if from_val != "" and to_val != "" do
                    %{from: from_val, to: to_val}
                  else
                    nil
                  end

                _ ->
                  sanitize(state, Map.get(params, field_name, ""))
              end

            cond do
              is_nil(value) or value == "" ->
                existing = Map.get(state.filter_values, filter.name)

                if (filter.type == :relation or filter.visible == false) and existing,
                  do: Map.put(acc, filter.name, existing),
                  else: acc

              RelationFilterHandler.skip_relation_search_term?(filter, value) ->
                existing = Map.get(state.filter_values, filter.name)
                if existing, do: Map.put(acc, filter.name, existing), else: acc

              true ->
                Map.put(acc, filter.name, value)
            end
          end)

        {filter_values, cleaned_relation_state} =
          MishkaGervaz.Helpers.invalidate_dependents(filter_values, state.filter_values, state)

        if filter_values == state.filter_values do
          {:noreply, socket}
        else
          state = %{state | relation_filter_state: cleaned_relation_state}
          socket = DataLoader.apply_filters(socket, state, filter_values)
          socket = apply_hook_result(state, :on_filter, [filter_values, socket], socket)
          {:noreply, socket}
        end
      end

      defp do_handle("remove_filter", %{"name" => name}, state, socket) do
        filter_name = String.to_existing_atom(name)
        new_filter_values = Map.delete(state.filter_values, filter_name)
        new_relation_state = Map.delete(state.relation_filter_state || %{}, filter_name)

        {new_filter_values, new_relation_state} =
          MishkaGervaz.Helpers.invalidate_dependents(
            new_filter_values,
            state.filter_values,
            state
          )

        state =
          %{
            State.update(state, filter_values: new_filter_values)
            | relation_filter_state: new_relation_state
          }

        socket = DataLoader.load_async(socket, state, page: 1, reset: true)
        socket = apply_hook_result(state, :on_filter, [new_filter_values, socket], socket)
        {:noreply, socket}
      end

      defp do_handle("clear_filters", _params, state, socket) do
        socket =
          %{State.update(state, filter_values: %{}) | relation_filter_state: %{}}
          |> then(&DataLoader.load_async(socket, &1, page: 1, reset: true))

        {:noreply, socket}
      end

      defp do_handle("archive_filter", params, state, socket) do
        status = params["status"] || params["value"]

        status_atom =
          case sanitize(state, status) do
            "archived" -> :archived
            _ -> :active
          end

        socket = DataLoader.apply_archive_status(socket, state, status_atom)
        {:noreply, socket}
      end

      defp do_handle("load_more", _params, state, socket) do
        socket = DataLoader.load_more(socket, state)
        {:noreply, socket}
      end

      defp do_handle("prev_page", _params, state, socket) do
        if state.page > 1 do
          socket = DataLoader.load_async(socket, state, page: state.page - 1, reset: true)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      defp do_handle("next_page", _params, state, socket) do
        has_more = state.has_more? or (state.total_pages && state.page < state.total_pages)

        if has_more do
          socket = DataLoader.load_async(socket, state, page: state.page + 1, reset: true)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      defp do_handle("go_to_page", %{"page" => page}, state, socket) do
        page_num = sanitize_page(state, page)

        max_page = state.total_pages || page_num
        page_num = max(1, min(page_num, max_page))

        if page_num != state.page do
          socket = DataLoader.load_async(socket, state, page: page_num, reset: true)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      defp do_handle("change_page_size", %{"size" => size}, state, socket) do
        page_size = sanitize_page(state, size)
        max = state.static.max_page_size
        options = state.static.page_size_options

        clamped = if max, do: min(page_size, max), else: page_size

        effective =
          if options && clamped not in options do
            state.static.page_size
          else
            clamped
          end

        state = State.update(state, current_page_size: effective)
        socket = DataLoader.load_async(socket, state, page: 1, reset: true)
        {:noreply, socket}
      end

      defp do_handle("delete", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        record = get_record(state, id, state.archive_status)

        if halted_before_action?(state, :before_row_action, :delete, [record, state]) do
          {:noreply, socket}
        else
          case run_hook(state, :before_delete, [record, state]) do
            {:halt, {:error, _reason}} ->
              {:noreply, socket}

            {:halt, {:confirm, _message}} ->
              do_delete(state, record, socket)

            _ ->
              do_delete(state, record, socket)
          end
        end
      end

      defp do_handle("destroy", params, state, socket) do
        do_handle("delete", params, state, socket)
      end

      defp do_handle("unarchive", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        record = get_record(state, id, :archived)

        if halted_before_action?(state, :before_row_action, :unarchive, [record, state]) do
          {:noreply, socket}
        else
          result = unarchive_record(state, record)
          run_action_hook(state, :after_row_action, :unarchive, [result, state])

          case result do
            {:ok, updated} ->
              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_success,
                  :unarchive,
                  [updated, state],
                  socket
                )

              socket = Phoenix.LiveView.stream_delete(socket, state.static.stream_name, record)
              socket = MishkaGervaz.Table.Web.AutoState.after_row_action(socket, state, :unarchive)
              {:noreply, socket}

            {:error, reason} ->
              error =
                Errors.Action.Failed.exception(
                  resource: state.static.resource,
                  action: :unarchive,
                  reason: reason,
                  record_id: id
                )

              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_error,
                  :unarchive,
                  [reason, state],
                  socket
                )

              socket = put_error_flash(socket, error)
              {:noreply, socket}
          end
        end
      end

      defp do_handle("permanent_destroy", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        record = get_record(state, id, :archived)

        if halted_before_action?(state, :before_row_action, :permanent_destroy, [record, state]) do
          {:noreply, socket}
        else
          result = permanent_destroy_record(state, record)
          run_action_hook(state, :after_row_action, :permanent_destroy, [result, state])

          case result do
            {:ok, destroyed} ->
              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_success,
                  :permanent_destroy,
                  [destroyed, state],
                  socket
                )

              socket = Phoenix.LiveView.stream_delete(socket, state.static.stream_name, record)

              socket =
                MishkaGervaz.Table.Web.AutoState.after_row_action(socket, state, :permanent_destroy)

              {:noreply, socket}

            {:error, reason} ->
              error =
                Errors.Action.Failed.exception(
                  resource: state.static.resource,
                  action: :permanent_destroy,
                  reason: reason,
                  record_id: id
                )

              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_error,
                  :permanent_destroy,
                  [reason, state],
                  socket
                )

              socket = put_error_flash(socket, error)
              {:noreply, socket}
          end
        end
      end

      defp do_handle("show_modal", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        send(self(), {:show_modal, id})
        {:noreply, socket}
      end

      defp do_handle("edit_modal", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        send(self(), {:edit_modal, id})
        {:noreply, socket}
      end

      defp do_handle("show_versions", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        send(self(), {:show_versions, id})
        {:noreply, socket}
      end

      defp do_handle("row_action", params, state, socket) do
        event_name = sanitize(state, params["event"])
        payload = params

        case run_hook(state, {:on_event, event_name}, [payload, state]) do
          {:ok, new_state} ->
            socket = Phoenix.Component.assign(socket, :table_state, new_state)
            {:noreply, socket}

          {:ok, :stream_insert, record} ->
            socket =
              Phoenix.LiveView.stream_insert(socket, state.static.stream_name, record, at: 0)

            {:noreply, socket}

          {:ok, :stream_delete, record} ->
            socket = Phoenix.LiveView.stream_delete(socket, state.static.stream_name, record)
            {:noreply, socket}

          {:ok, :stream_update, record} ->
            socket = Phoenix.LiveView.stream_insert(socket, state.static.stream_name, record)
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}

          {:send, message} ->
            send(self(), message)
            {:noreply, socket}

          _ ->
            case event_name do
              "permanent_destroy" ->
                do_handle("permanent_destroy", payload, state, socket)

              "unarchive" ->
                do_handle("unarchive", payload, state, socket)

              "delete" ->
                do_handle("delete", payload, state, socket)

              _ ->
                case find_row_action_by_event(state, event_name) do
                  %{type: :update, action: action} when not is_nil(action) ->
                    do_update(state, payload, action, socket)

                  %{type: :destroy, action: action} when not is_nil(action) ->
                    do_destroy(state, payload, action, socket)

                  %{type: :edit} ->
                    do_edit(state, payload, socket)

                  _ ->
                    send(self(), {:row_action, event_name, payload})
                    {:noreply, socket}
                end
            end
        end
      end

      defp do_edit(state, %{"id" => id}, socket) do
        form_id = FormInfo.component_id(state.static.resource)

        if form_id do
          Phoenix.LiveView.send_update(MishkaGervaz.Form.Web.Live,
            id: form_id,
            record_id: id
          )
        end

        {:noreply, socket}
      end

      @spec find_row_action_by_event(State.t(), String.t()) :: map() | nil
      defp find_row_action_by_event(state, event_name) do
        event_atom = String.to_existing_atom(event_name)

        matcher = fn action ->
          action.event == event_name or action.event == event_atom or
            (action.name == event_atom and is_nil(action.event))
        end

        Enum.find(state.static.row_actions, matcher) ||
          Enum.find_value(state.static.row_action_dropdowns, fn dropdown ->
            dropdown.items
            |> Enum.filter(&is_map_key(&1, :name))
            |> Enum.find(matcher)
          end)
      rescue
        ArgumentError -> nil
      end

      @spec do_update(State.t(), map(), atom(), Phoenix.LiveView.Socket.t()) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      defp do_update(state, %{"id" => id, "_action_name" => action_name} = params, action_spec, socket) do
        do_update_with_name(state, params, action_spec, socket, action_name)
      end

      defp do_update(state, %{"id" => _id} = params, action_spec, socket) do
        action_name = update_action_name(action_spec)
        do_update_with_name(state, params, action_spec, socket, action_name)
      end

      defp do_update_with_name(state, %{"id" => id}, action_spec, socket, action_name) do
        id = sanitize(state, id)
        record = get_record(state, id, state.archive_status)

        if halted_before_action?(state, :before_row_action, action_name, [record, state]) do
          {:noreply, socket}
        else
          result = update_record(state, record, action_spec)
          run_action_hook(state, :after_row_action, action_name, [result, state])

          case result do
            {:ok, updated} ->
              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_success,
                  action_name,
                  [updated, state],
                  socket
                )

              socket = Phoenix.LiveView.stream_insert(socket, state.static.stream_name, updated)
              {:noreply, socket}

            {:error, reason} ->
              error =
                Errors.Action.Failed.exception(
                  resource: state.static.resource,
                  action: :update,
                  reason: reason,
                  record_id: id
                )

              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_error,
                  action_name,
                  [reason, state],
                  socket
                )

              socket = put_error_flash(socket, error)
              {:noreply, socket}
          end
        end
      end

      @spec update_action_name(atom() | {atom(), atom()}) :: atom()
      defp update_action_name({_master, tenant}), do: tenant
      defp update_action_name(action) when is_atom(action), do: action

      @spec do_destroy(State.t(), map(), atom(), Phoenix.LiveView.Socket.t()) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      defp do_destroy(state, %{"id" => id}, action_spec, socket) do
        id = sanitize(state, id)
        record = get_record(state, id, state.archive_status)
        action_name = update_action_name(action_spec)

        if halted_before_action?(state, :before_row_action, action_name, [record, state]) do
          {:noreply, socket}
        else
          result = destroy_record(state, record, action_spec)
          run_action_hook(state, :after_row_action, action_name, [result, state])

          case result do
            {:ok, deleted} ->
              run_hook(state, :after_delete, [deleted, state])

              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_success,
                  action_name,
                  [deleted, state],
                  socket
                )

              socket =
                socket
                |> Phoenix.LiveView.stream_delete(state.static.stream_name, deleted)
                |> hide_row(state, record.id)

              socket = MishkaGervaz.Table.Web.AutoState.after_row_action(socket, state, action_name)
              {:noreply, socket}

            {:error, reason} ->
              error =
                Errors.Action.Failed.exception(
                  resource: state.static.resource,
                  action: :destroy,
                  reason: reason,
                  record_id: id
                )

              socket =
                apply_action_hook_socket(
                  state,
                  :on_row_action_error,
                  action_name,
                  [reason, state],
                  socket
                )

              socket = put_error_flash(socket, error)
              {:noreply, socket}
          end
        end
      end

      defp do_handle("custom_event", params, state, socket) do
        event_name = sanitize(state, params["event"])

        payload =
          case Jason.decode(params["values"] || "{}") do
            {:ok, values} -> values
            _ -> %{}
          end

        case run_hook(state, {:on_event, event_name}, [payload, state]) do
          {:ok, new_state} ->
            socket = Phoenix.Component.assign(socket, :table_state, new_state)
            {:noreply, socket}

          {:ok, :stream_insert, record} ->
            socket =
              Phoenix.LiveView.stream_insert(socket, state.static.stream_name, record, at: 0)

            {:noreply, socket}

          {:ok, :stream_delete, record} ->
            socket = Phoenix.LiveView.stream_delete(socket, state.static.stream_name, record)
            {:noreply, socket}

          {:ok, :stream_update, record} ->
            socket = Phoenix.LiveView.stream_insert(socket, state.static.stream_name, record)
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}

          {:send, message} ->
            send(self(), message)
            {:noreply, socket}

          _ ->
            send(self(), {:row_action, event_name, payload})
            {:noreply, socket}
        end
      end

      defp do_handle("expand_row", %{"id" => id}, state, socket) do
        id = sanitize(state, id)

        if id == state.expanded_id do
          record = get_record(state, id, state.archive_status)
          state = State.update(state, expanded_id: nil, expanded_data: nil)

          socket =
            socket
            |> Phoenix.LiveView.push_event("remove_expanded", %{
              id: "#{state.static.id}-expanded-tbody"
            })
            |> Phoenix.Component.assign(:table_state, state)

          socket = safe_stream_reinsert(socket, state, record)

          {:noreply, socket}
        else
          old_expanded_id = state.expanded_id

          state =
            State.update(state,
              expanded_id: id,
              expanded_data: Phoenix.LiveView.AsyncResult.loading()
            )

          socket = Phoenix.Component.assign(socket, :table_state, state)

          socket =
            if old_expanded_id do
              get_record(state, old_expanded_id, state.archive_status)
              |> then(&safe_stream_reinsert(socket, state, &1))
            else
              socket
            end

          socket =
            safe_stream_reinsert(socket, state, get_record(state, id, state.archive_status))

          case apply_hook_result(state, :on_expand, [id, socket], socket) do
            {:halt, socket} ->
              {:noreply, socket}

            socket ->
              send(self(), {:expand_row, id})
              {:noreply, socket}
          end
        end
      end

      @spec safe_stream_reinsert(Phoenix.LiveView.Socket.t(), State.t(), map() | nil) ::
              Phoenix.LiveView.Socket.t()
      defp safe_stream_reinsert(socket, _state, nil), do: socket

      defp safe_stream_reinsert(socket, state, record) do
        if Map.has_key?(socket.assigns, :streams) do
          Phoenix.LiveView.stream_insert(socket, state.static.stream_name, record)
        else
          socket
        end
      end

      defp do_handle("close_expanded", _params, state, socket) do
        old_expanded_id = state.expanded_id
        state = State.update(state, expanded_id: nil, expanded_data: nil)

        socket =
          socket
          |> Phoenix.LiveView.push_event("remove_expanded", %{
            id: "#{state.static.id}-expanded-tbody"
          })
          |> Phoenix.Component.assign(:table_state, state)

        socket =
          if old_expanded_id do
            get_record(state, old_expanded_id, state.archive_status)
            |> then(&safe_stream_reinsert(socket, state, &1))
          else
            socket
          end

        {:noreply, socket}
      end

      defp do_handle("toggle_select", %{"id" => id}, state, socket) do
        id = sanitize(state, id)
        state = toggle_select(state, id)
        record = get_record(state, id, state.archive_status)

        socket =
          socket
          |> Phoenix.Component.assign(:table_state, state)
          |> Phoenix.LiveView.stream_insert(state.static.stream_name, record)

        socket = apply_hook_result(state, :on_select, [state.selected_ids, socket], socket)

        {:noreply, socket}
      end

      defp do_handle("toggle_select_all", _params, state, socket) do
        state = toggle_select_all(state)
        socket = Phoenix.Component.assign(socket, :table_state, state)
        socket = apply_hook_result(state, :on_select, [state.selected_ids, socket], socket)

        {:noreply, socket}
      end

      defp do_handle("clear_selection", _params, state, socket) do
        state = clear_selection(state)
        socket = Phoenix.Component.assign(socket, :table_state, state)
        socket = apply_hook_result(state, :on_select, [state.selected_ids, socket], socket)

        {:noreply, socket}
      end

      defp do_handle("switch_template", %{"template" => template_name}, state, socket) do
        template_atom =
          case sanitize(state, template_name) do
            "table" -> :table
            "media_gallery" -> :media_gallery
            name -> String.to_existing_atom(name)
          end

        case State.switch_template(state, template_atom) do
          {:ok, new_state} ->
            socket = DataLoader.load_async(socket, new_state, page: 1, reset: true)
            {:noreply, socket}

          {:error, :template_not_allowed} ->
            {:noreply, socket}
        end
      rescue
        ArgumentError ->
          {:noreply, socket}
      end

      defp do_handle("bulk_action", %{"action" => action_name}, state, socket) do
        action_name = sanitize(state, action_name)
        action_atom = String.to_existing_atom(action_name)
        bulk_action = Enum.find(state.static.bulk_actions, fn a -> a.name == action_atom end)
        selected_ids = get_selected_ids(state)

        if halted_before_action?(state, :before_bulk_action, action_atom, [selected_ids, state]) do
          {:noreply, socket}
        else
          case run_hook(state, {:on_bulk_action, action_name}, [selected_ids, state]) do
            {:ok, new_state} ->
              socket = Phoenix.Component.assign(socket, :table_state, new_state)
              {:noreply, socket}

            {:send, message} ->
              send(self(), message)
              {:noreply, socket}

            _ ->
              execute_bulk_action(bulk_action, selected_ids, state, socket)
          end
        end
      end

      defp do_handle("relation_" <> action, params, state, socket) do
        relation_filter_handler(state).handle(action, params, state, socket)
      end

      defp do_handle(event, params, _state, socket) do
        send(self(), {:table_event, event, params})
        {:noreply, socket}
      end

      @spec do_delete(State.t(), map(), Phoenix.LiveView.Socket.t()) ::
              {:noreply, Phoenix.LiveView.Socket.t()}
      defp do_delete(state, record, socket) do
        result = delete_record(state, record)
        run_action_hook(state, :after_row_action, :delete, [result, state])

        case result do
          {:ok, deleted} ->
            run_hook(state, :after_delete, [deleted, state])

            socket =
              apply_action_hook_socket(
                state,
                :on_row_action_success,
                :delete,
                [deleted, state],
                socket
              )

            socket =
              socket
              |> Phoenix.LiveView.stream_delete(state.static.stream_name, deleted)
              |> hide_row(state, record.id)

            socket = MishkaGervaz.Table.Web.AutoState.after_row_action(socket, state, :delete)
            {:noreply, socket}

          {:error, reason} ->
            error =
              Errors.Action.Failed.exception(
                resource: state.static.resource,
                action: :destroy,
                reason: reason,
                record_id: record.id
              )

            socket =
              apply_action_hook_socket(
                state,
                :on_row_action_error,
                :delete,
                [reason, state],
                socket
              )

            socket = put_error_flash(socket, error)
            {:noreply, socket}
        end
      end

      @spec hide_row(Phoenix.LiveView.Socket.t(), State.t(), String.t()) ::
              Phoenix.LiveView.Socket.t()
      defp hide_row(socket, state, id) do
        dom_id = "#{state.static.stream_name}-#{id}"
        Phoenix.LiveView.push_event(socket, "hide_row", %{id: dom_id})
      end

      defoverridable handle: 3
    end
  end

  @doc """
  Main event handler dispatcher.

  Called from LiveComponent's handle_event callback.
  """
  @spec handle(String.t(), map(), socket()) :: {:noreply, socket()}
  def handle(event, params, socket) do
    MishkaGervaz.Table.Web.Events.Default.handle(event, params, socket)
  end
end

defmodule MishkaGervaz.Table.Web.Events.Default do
  @moduledoc false
  @dialyzer :no_match
  use MishkaGervaz.Table.Web.Events
end
