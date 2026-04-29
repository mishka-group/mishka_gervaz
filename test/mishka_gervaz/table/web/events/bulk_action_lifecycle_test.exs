defmodule MishkaGervaz.Table.Web.Events.BulkActionLifecycleTest do
  @moduledoc """
  Tests for per-action bulk lifecycle hooks (`before_/after_/on_*_success/error`)
  exercised through the function-handler path (no DB needed).
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Events.BulkActionHandler
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.State.Static
  alias MishkaGervaz.Resource.Info.Table, as: Info

  defp socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{assigns: Map.merge(%{__changed__: %{}}, assigns)}
  end

  defp build_state(hooks_map) do
    resource = MishkaGervaz.Test.Resources.Post
    config = Info.config(resource)

    static = %Static{
      id: "test-table",
      resource: resource,
      stream_name: :test_stream,
      config: config,
      columns: [],
      filters: [],
      row_actions: [],
      row_action_dropdowns: [],
      row_actions_layout: :inline,
      bulk_actions: [],
      ui_adapter: MishkaGervaz.UIAdapters.Tailwind,
      ui_adapter_opts: [],
      switchable_templates: [],
      template_options: %{},
      features: [],
      filter_groups: [],
      filter_mode: :inline,
      pagination_ui: :simple,
      theme: nil,
      sortable_columns: [],
      sort_field_map: %{},
      hooks: hooks_map,
      url_sync_config: nil,
      page_size: 20
    }

    %State{
      static: static,
      current_user: %{id: "u-1", site_id: nil, role: :admin},
      master_user?: true,
      preload_aliases: %{},
      supports_archive: false,
      template: MishkaGervaz.Table.Templates.Standard,
      loading: :loaded,
      loading_type: :full,
      has_initial_data?: true,
      records_result: nil,
      page: 1,
      has_more?: false,
      total_count: 5,
      total_pages: 1,
      filter_values: %{},
      sort_fields: [],
      archive_status: :active,
      relation_filter_state: %{},
      selected_ids: MapSet.new(["a", "b"]),
      excluded_ids: MapSet.new(),
      select_all?: false,
      expanded_id: nil,
      expanded_data: nil,
      path_params: %{},
      base_path: "/admin/posts",
      preserved_params: %{},
      saved_active_state: nil,
      saved_archived_state: nil
    }
  end

  describe "function-handler path — after_bulk_action" do
    test "fires after_bulk_action with the result tuple on success" do
      test_pid = self()

      handler = fn _ids, state -> {:ok, state} end

      hooks = %{
        {:after_bulk_action, :do_thing} => fn result, _state ->
          send(test_pid, {:after, result})
          :ok
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, ["a", "b"], state, socket())

      assert_received {:after, {:ok, %State{}}}
    end

    test "fires after_bulk_action with the result tuple on error" do
      test_pid = self()

      handler = fn _ids, _state -> {:error, :boom} end

      hooks = %{
        {:after_bulk_action, :do_thing} => fn result, _state ->
          send(test_pid, {:after, result})
          :ok
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, ["a", "b"], state, socket())

      assert_received {:after, {:error, :boom}}
    end

    test "fires after_bulk_action with :reload" do
      test_pid = self()

      handler = fn _ids, _state -> :reload end

      hooks = %{
        {:after_bulk_action, :do_thing} => fn result, _state ->
          send(test_pid, {:after, result})
          :ok
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, [], state, socket())

      assert_received {:after, :reload}
    end
  end

  describe "function-handler path — on_bulk_action_success" do
    test "fires on success with a State result" do
      test_pid = self()

      handler = fn _ids, state -> {:ok, state} end

      hooks = %{
        {:on_bulk_action_success, :do_thing} => fn _result, _state ->
          send(test_pid, :success)
          nil
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, ["a"], state, socket())

      assert_received :success
    end

    test "fires on success with :reload" do
      test_pid = self()

      handler = fn _ids, _state -> :reload end

      hooks = %{
        {:on_bulk_action_success, :do_thing} => fn _result, _state ->
          send(test_pid, :success_reload)
          nil
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, [], state, socket())

      assert_received :success_reload
    end

    test "fires on success with :ok return" do
      test_pid = self()

      handler = fn _ids, _state -> :ok end

      hooks = %{
        {:on_bulk_action_success, :do_thing} => fn _result, _state ->
          send(test_pid, :success_ok)
          nil
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, [], state, socket())

      assert_received :success_ok
    end

    test "does NOT fire on success when error" do
      test_pid = self()

      handler = fn _ids, _state -> {:error, :boom} end

      hooks = %{
        {:on_bulk_action_success, :do_thing} => fn _result, _state ->
          send(test_pid, :should_not_fire)
          nil
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, [], state, socket())

      refute_received :should_not_fire
    end
  end

  describe "function-handler path — on_bulk_action_error" do
    test "fires on error with the reason" do
      test_pid = self()

      handler = fn _ids, _state -> {:error, :validation_failed} end

      hooks = %{
        {:on_bulk_action_error, :do_thing} => fn reason, _state ->
          send(test_pid, {:error_hook, reason})
          nil
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, [], state, socket())

      assert_received {:error_hook, :validation_failed}
    end

    test "does NOT fire on error when success" do
      test_pid = self()

      handler = fn _ids, state -> {:ok, state} end

      hooks = %{
        {:on_bulk_action_error, :do_thing} => fn _reason, _state ->
          send(test_pid, :should_not_fire)
          nil
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      BulkActionHandler.Default.execute(action, [], state, socket())

      refute_received :should_not_fire
    end
  end

  describe "on_bulk_action_success / error can mutate the socket" do
    test "success hook returning a socket replaces the default socket" do
      handler = fn _ids, state -> {:ok, state} end

      hooks = %{
        {:on_bulk_action_success, :do_thing} => fn _result, _state ->
          %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flashed: :success}}
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      {:noreply, result_socket} =
        BulkActionHandler.Default.execute(action, [], state, socket())

      assert result_socket.assigns.flashed == :success
    end

    test "error hook returning a socket replaces the default socket" do
      handler = fn _ids, _state -> {:error, :nope} end

      hooks = %{
        {:on_bulk_action_error, :do_thing} => fn _reason, _state ->
          %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flashed: :error}}
        end
      }

      state = build_state(hooks)
      action = %{name: :do_thing, handler: handler}

      {:noreply, result_socket} =
        BulkActionHandler.Default.execute(action, [], state, socket())

      assert result_socket.assigns.flashed == :error
    end
  end

  describe "no lifecycle wiring when hooks not configured" do
    test "function handler with no hooks runs normally" do
      handler = fn _ids, state -> {:ok, state} end

      state = build_state(%{})
      action = %{name: :do_thing, handler: handler}

      assert {:noreply, _} = BulkActionHandler.Default.execute(action, [], state, socket())
    end
  end
end
