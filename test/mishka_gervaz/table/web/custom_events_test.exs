defmodule MishkaGervaz.Table.Web.CustomEventsTest do
  @moduledoc """
  Tests for custom Events module integration.
  """
  # async: false to prevent ETS race conditions with shared test resources
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.Events

  # Custom Events Module Tests

  defmodule TrackingEventsModule do
    @moduledoc """
    Custom Events module that tracks all handled events.
    Uses `use MishkaGervaz.Table.Web.Events` to inherit default behavior.
    """
    use MishkaGervaz.Table.Web.Events

    @impl true
    def handle(event, params, socket) do
      # Send tracking message before handling
      send(self(), {:custom_events_tracked, event, params})
      # Call default implementation via super
      super(event, params, socket)
    end
  end

  defmodule InterceptingEventsModule do
    @moduledoc """
    Custom Events module that intercepts specific events.
    """
    use MishkaGervaz.Table.Web.Events

    @impl true
    def handle("intercept_me", params, socket) do
      send(self(), {:intercepted, params})
      {:noreply, socket}
    end

    def handle(event, params, socket) do
      super(event, params, socket)
    end
  end

  defmodule TransformingEventsModule do
    @moduledoc """
    Custom Events module that transforms params before handling.
    """
    use MishkaGervaz.Table.Web.Events

    @impl true
    def handle(event, params, socket) do
      # Transform params - add a custom key
      transformed_params = Map.put(params, "transformed", true)
      send(self(), {:params_transformed, event, transformed_params})
      super(event, transformed_params, socket)
    end
  end

  # Custom Sub-Builder Tests - SanitizationHandler

  defmodule UppercaseSanitizationHandler do
    @moduledoc """
    Custom sanitization that converts all strings to uppercase.
    """
    use MishkaGervaz.Table.Web.Events.SanitizationHandler

    @impl true
    def sanitize(value) when is_binary(value) do
      value
      |> HtmlSanitizeEx.strip_tags()
      |> String.upcase()
    rescue
      _ -> value
    end

    def sanitize(value), do: value
  end

  defmodule PrefixSanitizationHandler do
    @moduledoc """
    Custom sanitization that adds prefix to sanitized values.
    """
    use MishkaGervaz.Table.Web.Events.SanitizationHandler

    @impl true
    def sanitize(value) when is_binary(value) do
      cleaned = HtmlSanitizeEx.strip_tags(value)
      "sanitized:#{cleaned}"
    rescue
      _ -> value
    end

    def sanitize(value), do: value

    @impl true
    def sanitize_column(column) when is_binary(column) do
      # Custom column sanitization - lowercase and atomize
      column
      |> sanitize()
      |> String.downcase()
      |> String.to_existing_atom()
    rescue
      _ -> :unknown_column
    end

    def sanitize_column(column) when is_atom(column), do: column
    def sanitize_column(_), do: :unknown_column
  end

  defmodule NoOpSanitizationHandler do
    @moduledoc """
    No-op sanitization - returns values unchanged (for testing purposes).
    """
    use MishkaGervaz.Table.Web.Events.SanitizationHandler

    @impl true
    def sanitize(value), do: value
  end

  # Custom Sub-Builder Tests - SelectionHandler

  defmodule LimitedSelectionHandler do
    @moduledoc """
    Custom selection handler that limits selection to max 3 items.
    """
    use MishkaGervaz.Table.Web.Events.SelectionHandler

    @impl true
    def toggle_select(state, id) do
      if MapSet.size(state.selected_ids) >= 3 and
           not MapSet.member?(state.selected_ids, id) do
        # Don't allow more than 3 selections
        send(self(), {:selection_limit_reached, id})
        state
      else
        super(state, id)
      end
    end
  end

  defmodule TrackingSelectionHandler do
    @moduledoc """
    Selection handler that tracks all selection operations.
    """
    use MishkaGervaz.Table.Web.Events.SelectionHandler

    @impl true
    def toggle_select(state, id) do
      send(self(), {:selection_toggled, id})
      super(state, id)
    end

    @impl true
    def toggle_select_all(state) do
      send(self(), {:select_all_toggled, state.select_all?})
      super(state)
    end

    @impl true
    def clear_selection(state) do
      send(self(), {:selection_cleared})
      super(state)
    end
  end

  # Custom Sub-Builder Tests - RecordHandler

  defmodule AuditingRecordHandler do
    @moduledoc """
    Record handler that audits all record operations.
    """
    use MishkaGervaz.Table.Web.Events.RecordHandler

    @impl true
    def get_record(state, id, archive_status) do
      send(self(), {:record_accessed, state.static.resource, id})
      super(state, id, archive_status)
    end

    @impl true
    def delete_record(state, record) do
      send(self(), {:record_deleting, record.id})
      result = super(state, record)
      send(self(), {:record_deleted, record.id, result})
      result
    end
  end

  defmodule BlockingRecordHandler do
    @moduledoc """
    Record handler that blocks deletions based on custom logic.
    """
    use MishkaGervaz.Table.Web.Events.RecordHandler

    @impl true
    def delete_record(_state, _record) do
      send(self(), :deletion_blocked)
      {:error, :deletion_not_allowed}
    end
  end

  # Custom Sub-Builder Tests - BulkActionHandler

  defmodule LoggingBulkActionHandler do
    @moduledoc """
    Bulk action handler that logs all bulk operations.
    """
    use MishkaGervaz.Table.Web.Events.BulkActionHandler

    @impl true
    def execute(action, selected_ids, state, socket) do
      send(self(), {:bulk_action_executed, action, selected_ids})
      super(action, selected_ids, state, socket)
    end
  end

  # Custom Sub-Builder Tests - HookRunner

  defmodule EnhancedHookRunner do
    @moduledoc """
    Hook runner that adds timing information.
    """
    use MishkaGervaz.Table.Web.Events.HookRunner

    @impl true
    def run_hook(hooks, hook_name, args) do
      start = System.monotonic_time(:microsecond)
      result = super(hooks, hook_name, args)
      duration = System.monotonic_time(:microsecond) - start
      send(self(), {:hook_timed, duration})
      result
    end
  end

  # Use existing test resources from DataLoader tests
  alias MishkaGervaz.Test.DataLoader.BasicResource, as: TestResource

  # Test Helpers

  defp master_user, do: %{id: "master-123", site_id: nil, role: :admin}

  defp create_test_data(count) do
    Enum.map(1..count, fn i ->
      Ash.create!(TestResource, %{name: "Item #{i}"})
    end)
  end

  defp clear_ets do
    try do
      Ash.DataLayer.Ets.stop(TestResource)
    rescue
      _ -> :ok
    end
  end

  defp create_socket(state) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        table_state: state,
        flash: %{},
        live_action: :index
      },
      private: %{
        lifecycle: %{handle_event: [], after_render: []},
        assign_new: %{},
        changed: %{},
        connected?: true,
        live_temp: %{}
      },
      endpoint: MishkaGervazWeb.Endpoint,
      id: "test-socket",
      root_pid: self(),
      router: nil,
      view: nil
    }
  end

  defp init_state(opts \\ []) do
    state = State.init("test-id", TestResource, master_user())

    updates =
      Keyword.merge(
        [
          loading: :loaded,
          has_initial_data?: true,
          page: 1
        ],
        opts
      )

    State.update(state, updates)
  end

  setup do
    on_exit(fn -> clear_ets() end)
    :ok
  end

  # Custom Events Module Tests

  describe "Custom Events module inheritance" do
    test "custom module using use MishkaGervaz.Table.Web.Events inherits handle/3" do
      # Verify module has the callback
      assert function_exported?(TrackingEventsModule, :handle, 3)
    end

    test "custom module can track all events via override" do
      state = init_state()
      socket = create_socket(state)

      {:noreply, _socket} = TrackingEventsModule.handle("toggle_select_all", %{}, socket)

      assert_received {:custom_events_tracked, "toggle_select_all", %{}}
    end

    test "custom module can intercept specific events" do
      state = init_state()
      socket = create_socket(state)

      {:noreply, _socket} =
        InterceptingEventsModule.handle("intercept_me", %{"key" => "value"}, socket)

      assert_received {:intercepted, %{"key" => "value"}}
      # Should NOT receive table_event since we intercepted it
      refute_received {:table_event, "intercept_me", _}
    end

    test "custom module falls through to default handler for non-intercepted events" do
      state = init_state()
      socket = create_socket(state)

      {:noreply, updated_socket} =
        InterceptingEventsModule.handle("toggle_select_all", %{}, socket)

      # Default behavior should have run
      updated_state = updated_socket.assigns.table_state
      assert updated_state.select_all? == true
    end

    test "custom module can transform params before handling" do
      state = init_state()
      socket = create_socket(state)

      {:noreply, _socket} = TransformingEventsModule.handle("toggle_select_all", %{}, socket)

      assert_received {:params_transformed, "toggle_select_all", params}
      assert params["transformed"] == true
    end

    test "multiple custom modules can coexist" do
      state = init_state()
      socket = create_socket(state)

      # Both should work independently
      {:noreply, _} = TrackingEventsModule.handle("toggle_select_all", %{}, socket)
      assert_received {:custom_events_tracked, "toggle_select_all", %{}}

      {:noreply, _} = InterceptingEventsModule.handle("intercept_me", %{}, socket)
      assert_received {:intercepted, %{}}
    end
  end

  # SanitizationHandler Tests

  describe "Custom SanitizationHandler inheritance" do
    test "uppercase handler converts to uppercase" do
      result = UppercaseSanitizationHandler.sanitize("hello world")
      assert result == "HELLO WORLD"
    end

    test "uppercase handler strips HTML tags" do
      result = UppercaseSanitizationHandler.sanitize("<script>test</script>")
      assert result == "TEST"
    end

    test "prefix handler adds sanitized: prefix" do
      result = PrefixSanitizationHandler.sanitize("test value")
      assert result == "sanitized:test value"
    end

    test "prefix handler strips HTML and adds prefix" do
      result = PrefixSanitizationHandler.sanitize("<b>bold</b>")
      assert result == "sanitized:bold"
    end

    test "custom sanitize_column returns :unknown_column for invalid" do
      result = PrefixSanitizationHandler.sanitize_column("nonexistent_column_xyz")
      assert result == :unknown_column
    end

    test "noop handler returns value unchanged" do
      result = NoOpSanitizationHandler.sanitize("<script>dangerous</script>")
      assert result == "<script>dangerous</script>"
    end

    test "handlers preserve non-binary values" do
      assert UppercaseSanitizationHandler.sanitize(123) == 123
      assert UppercaseSanitizationHandler.sanitize(:atom) == :atom
      assert UppercaseSanitizationHandler.sanitize(nil) == nil
    end

    test "default handler has sanitize_page/1" do
      # Test the default implementation
      alias MishkaGervaz.Table.Web.Events.SanitizationHandler.Default
      assert Default.sanitize_page("5") == 5
      assert Default.sanitize_page(10) == 10
      # Non-integer, non-binary values return 1
      assert Default.sanitize_page(nil) == 1
      assert Default.sanitize_page(:atom) == 1
      # Invalid string raises ArgumentError (String.to_integer behavior)
      assert_raise ArgumentError, fn -> Default.sanitize_page("invalid") end
    end
  end

  # SelectionHandler Tests

  describe "Custom SelectionHandler inheritance" do
    test "limited handler blocks selection after limit" do
      state = init_state(selected_ids: MapSet.new(["a", "b", "c"]))

      new_state = LimitedSelectionHandler.toggle_select(state, "d")

      # Should not add "d" because limit is 3
      refute MapSet.member?(new_state.selected_ids, "d")
      assert_received {:selection_limit_reached, "d"}
    end

    test "limited handler allows toggle when under limit" do
      state = init_state(selected_ids: MapSet.new(["a"]))

      new_state = LimitedSelectionHandler.toggle_select(state, "b")

      assert MapSet.member?(new_state.selected_ids, "b")
    end

    test "limited handler allows deselection" do
      state = init_state(selected_ids: MapSet.new(["a", "b", "c"]))

      new_state = LimitedSelectionHandler.toggle_select(state, "a")

      # Should allow deselecting "a"
      refute MapSet.member?(new_state.selected_ids, "a")
    end

    test "tracking handler tracks toggle_select" do
      state = init_state()

      _new_state = TrackingSelectionHandler.toggle_select(state, "test-id")

      assert_received {:selection_toggled, "test-id"}
    end

    test "tracking handler tracks toggle_select_all" do
      state = init_state(select_all?: false)

      _new_state = TrackingSelectionHandler.toggle_select_all(state)

      assert_received {:select_all_toggled, false}
    end

    test "tracking handler tracks clear_selection" do
      state = init_state(selected_ids: MapSet.new(["a", "b"]))

      _new_state = TrackingSelectionHandler.clear_selection(state)

      assert_received {:selection_cleared}
    end

    test "custom handler preserves default get_selected_ids behavior" do
      state = init_state(selected_ids: MapSet.new(["a", "b"]))

      ids = TrackingSelectionHandler.get_selected_ids(state)

      assert ids == ["a", "b"] or ids == ["b", "a"]
    end
  end

  # RecordHandler Tests

  describe "Custom RecordHandler inheritance" do
    test "auditing handler tracks record access" do
      [record | _] = create_test_data(3)
      state = init_state()

      _result = AuditingRecordHandler.get_record(state, record.id, :active)

      assert_received {:record_accessed, TestResource, id}
      assert id == record.id
    end

    test "auditing handler tracks deletion" do
      [record | _] = create_test_data(3)
      state = init_state()

      _result = AuditingRecordHandler.delete_record(state, record)

      assert_received {:record_deleting, id}
      assert id == record.id
      assert_received {:record_deleted, ^id, _result}
    end

    test "blocking handler prevents deletion" do
      [record | _] = create_test_data(3)
      state = init_state()

      result = BlockingRecordHandler.delete_record(state, record)

      assert result == {:error, :deletion_not_allowed}
      assert_received :deletion_blocked

      # Record should still exist
      assert Ash.get!(TestResource, record.id)
    end
  end

  # BulkActionHandler Tests

  describe "Custom BulkActionHandler inheritance" do
    test "logging handler logs bulk action execution" do
      state =
        init_state(
          selected_ids: MapSet.new(["id1", "id2"]),
          bulk_actions: [%{name: :export, handler: :parent}]
        )

      socket = create_socket(state)

      bulk_action = %{name: :export, handler: :parent}

      {:noreply, _socket} =
        LoggingBulkActionHandler.execute(bulk_action, ["id1", "id2"], state, socket)

      assert_received {:bulk_action_executed, ^bulk_action, ["id1", "id2"]}
    end

    test "logging handler passes through to parent handler" do
      state = init_state()
      socket = create_socket(state)

      bulk_action = %{name: :test_action, handler: :parent}

      {:noreply, _socket} =
        LoggingBulkActionHandler.execute(bulk_action, ["id1"], state, socket)

      # Should send to parent
      assert_received {:bulk_action, :test_action, ["id1"]}
    end
  end

  # HookRunner Tests

  describe "Custom HookRunner inheritance" do
    test "enhanced hook runner tracks timing" do
      state = init_state()
      socket = create_socket(state)

      hooks = %{on_test: fn socket -> socket end}

      _result = EnhancedHookRunner.run_hook(hooks, :on_test, [socket])

      assert_received {:hook_timed, duration}
      assert is_integer(duration)
      assert duration >= 0
    end

    test "hook runner preserves halt behavior" do
      state = init_state()
      socket = create_socket(state)

      hooks = %{on_test: fn _socket -> {:halt, :stopped} end}

      result = EnhancedHookRunner.run_hook(hooks, :on_test, [socket])

      assert result == {:halt, :stopped}
    end

    test "hook runner returns nil when hook not found" do
      hooks = %{on_other: fn -> :ok end}

      result = EnhancedHookRunner.run_hook(hooks, :on_test, [])

      assert result == nil
    end
  end

  # Default Module Fallback Tests

  describe "Default module fallback" do
    test "Events.handle/3 delegates to Default module" do
      state = init_state()
      socket = create_socket(state)

      {:noreply, updated_socket} = Events.handle("toggle_select_all", %{}, socket)

      updated_state = updated_socket.assigns.table_state
      assert updated_state.select_all? == true
    end

    test "Default SanitizationHandler is used when no custom configured" do
      alias MishkaGervaz.Table.Web.Events.SanitizationHandler.Default

      result = Default.sanitize("<script>test</script>")
      assert result == "test"
    end

    test "Default SelectionHandler provides expected behavior" do
      alias MishkaGervaz.Table.Web.Events.SelectionHandler.Default

      state = init_state()
      new_state = Default.toggle_select(state, "test-id")

      assert MapSet.member?(new_state.selected_ids, "test-id")
    end
  end

  # Sub-Builder Behavior Verification

  describe "Sub-builder behavior contracts" do
    test "SanitizationHandler defines required callbacks" do
      behaviours = MishkaGervaz.Table.Web.Events.SanitizationHandler.behaviour_info(:callbacks)

      assert {:sanitize, 1} in behaviours
      assert {:sanitize_column, 1} in behaviours
      assert {:sanitize_page, 1} in behaviours
    end

    test "SelectionHandler defines required callbacks" do
      behaviours = MishkaGervaz.Table.Web.Events.SelectionHandler.behaviour_info(:callbacks)

      assert {:toggle_select, 2} in behaviours
      assert {:toggle_select_all, 1} in behaviours
      assert {:clear_selection, 1} in behaviours
      assert {:get_selected_ids, 1} in behaviours
    end

    test "RecordHandler defines required callbacks" do
      behaviours = MishkaGervaz.Table.Web.Events.RecordHandler.behaviour_info(:callbacks)

      assert {:get_record, 3} in behaviours
      assert {:delete_record, 2} in behaviours
      assert {:unarchive_record, 2} in behaviours
      assert {:permanent_destroy_record, 2} in behaviours
    end

    test "BulkActionHandler defines required callbacks" do
      behaviours = MishkaGervaz.Table.Web.Events.BulkActionHandler.behaviour_info(:callbacks)

      assert {:execute, 4} in behaviours
    end

    test "HookRunner defines required callbacks" do
      behaviours = MishkaGervaz.Table.Web.Events.HookRunner.behaviour_info(:callbacks)

      assert {:run_hook, 3} in behaviours
      assert {:apply_hook_result, 4} in behaviours
    end
  end

  # Edge Cases and Error Handling

  describe "Edge cases and error handling" do
    test "custom handler handles nil values gracefully" do
      assert UppercaseSanitizationHandler.sanitize(nil) == nil
    end

    test "custom handler handles empty string" do
      assert UppercaseSanitizationHandler.sanitize("") == ""
    end

    test "selection handler handles empty MapSet" do
      state = init_state(selected_ids: MapSet.new())

      new_state = LimitedSelectionHandler.toggle_select(state, "first")

      assert MapSet.member?(new_state.selected_ids, "first")
    end

    test "custom events module handles unknown events via fallback" do
      state = init_state()
      socket = create_socket(state)

      {:noreply, _socket} = TrackingEventsModule.handle("unknown_event_xyz", %{}, socket)

      # Should receive tracking message
      assert_received {:custom_events_tracked, "unknown_event_xyz", %{}}
      # And the default fallback should send table_event
      assert_received {:table_event, "unknown_event_xyz", %{}}
    end
  end
end
