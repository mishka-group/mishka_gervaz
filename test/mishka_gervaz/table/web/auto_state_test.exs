defmodule MishkaGervaz.Table.Web.AutoStateTest do
  @moduledoc """
  Pure-function tests for built-in state-transition rules.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.AutoState
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.State.Static
  alias MishkaGervaz.Resource.Info.Table, as: Info

  defp socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{assigns: Map.merge(%{__changed__: %{}}, assigns)}
  end

  defp build_state(opts) do
    builtins = Keyword.get(opts, :builtins, %{})
    archive_status = Keyword.get(opts, :archive_status, :active)
    total_count = Keyword.get(opts, :total_count, 5)
    page = Keyword.get(opts, :page, 1)

    resource = MishkaGervaz.Test.Resources.Post
    config = Info.config(resource)

    hooks = if map_size(builtins) > 0, do: %{__builtins__: builtins}, else: %{}

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
      hooks: hooks,
      url_sync_config: nil,
      page_size: 20
    }

    %State{
      static: static,
      current_user: %{id: "u-1", site_id: nil, role: :admin},
      master_user?: true,
      preload_aliases: %{},
      supports_archive: true,
      template: MishkaGervaz.Table.Templates.Standard,
      loading: :loaded,
      loading_type: :full,
      has_initial_data?: true,
      records_result: nil,
      page: page,
      has_more?: false,
      total_count: total_count,
      total_pages: 1,
      filter_values: %{},
      sort_fields: [],
      archive_status: archive_status,
      relation_filter_state: %{},
      selected_ids: MapSet.new(),
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

  describe "config/1 + enabled?/2 + value/2" do
    test "config returns the builtins map when configured" do
      state = build_state(builtins: %{switch_to_active_on_empty_archive: true})
      assert AutoState.config(state) == %{switch_to_active_on_empty_archive: true}
    end

    test "config falls back to clear_selection_after_bulk: true when no builtins" do
      state = build_state([])
      assert AutoState.config(state) == %{clear_selection_after_bulk: true}
    end

    test "enabled? returns true only when flag is exactly true" do
      state =
        build_state(
          builtins: %{
            switch_to_active_on_empty_archive: true,
            switch_to_archive_on_empty_active: false,
            redirect_on_empty: nil
          }
        )

      assert AutoState.enabled?(state, :switch_to_active_on_empty_archive)
      refute AutoState.enabled?(state, :switch_to_archive_on_empty_active)
      refute AutoState.enabled?(state, :redirect_on_empty)
      refute AutoState.enabled?(state, :unknown_key)
    end

    test "value returns the raw value (string, fun, nil)" do
      state = build_state(builtins: %{redirect_on_empty: "/dashboard"})
      assert AutoState.value(state, :redirect_on_empty) == "/dashboard"

      fun = fn _ -> "/elsewhere" end
      state = build_state(builtins: %{redirect_on_empty: fun})
      assert AutoState.value(state, :redirect_on_empty) == fun

      state = build_state(builtins: %{})
      assert AutoState.value(state, :redirect_on_empty) == nil
    end
  end

  describe "after_row_action/3 — arming behavior" do
    test "arms socket when any post-load rule is enabled" do
      state = build_state(builtins: %{switch_to_active_on_empty_archive: true})
      result = AutoState.after_row_action(socket(), state, :unarchive)

      assert is_struct(result, Phoenix.LiveView.Socket)
      armed = result.assigns[:__auto_state_armed__]
      assert armed == %{action: :unarchive, kind: :row}
    end

    test "does NOT arm or reload when no post-load rule is enabled" do
      state = build_state(builtins: %{clear_selection_after_bulk: true})
      result = AutoState.after_row_action(socket(), state, :delete)

      assert result == socket()
    end

    test "arms even when only redirect_on_empty is configured" do
      state = build_state(builtins: %{redirect_on_empty: "/x"})
      result = AutoState.after_row_action(socket(), state, :delete)

      armed = result.assigns[:__auto_state_armed__]
      assert armed.action == :delete
    end
  end

  describe "after_bulk_action/3 — arming behavior" do
    test "arms socket using bulk action's name" do
      state = build_state(builtins: %{switch_to_active_on_empty_archive: true})
      result = AutoState.after_bulk_action(socket(), state, %{name: :unarchive})

      armed = result.assigns[:__auto_state_armed__]
      assert armed == %{action: :unarchive, kind: :bulk}
    end

    test "no-op when no post-load rules enabled" do
      state = build_state(builtins: %{})
      assert AutoState.after_bulk_action(socket(), state, %{name: :destroy}) == socket()
    end

    test "no-op when action is nil" do
      state = build_state(builtins: %{switch_to_active_on_empty_archive: true})
      assert AutoState.after_bulk_action(socket(), state, nil) == socket()
    end
  end

  describe "after_load/2 — switch_to_active_on_empty_archive" do
    test "switches to :active when archive empty + armed by :unarchive" do
      state =
        build_state(
          builtins: %{switch_to_active_on_empty_archive: true},
          archive_status: :archived,
          total_count: 0
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{
          action: :unarchive,
          kind: :row
        })
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)

      # Mode switch triggers a load_async which sets table_state to a new copy;
      # archive_status on the new state should be :active.
      assert result.assigns.table_state.archive_status == :active
      # Armed flag should be cleared.
      assert result.assigns[:__auto_state_armed__] == nil
    end

    test "does NOT switch when archive_status is :active" do
      state =
        build_state(
          builtins: %{switch_to_active_on_empty_archive: true},
          archive_status: :active,
          total_count: 0
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{action: :unarchive, kind: :row})
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.archive_status == :active
    end

    test "does NOT switch when total_count > 0" do
      state =
        build_state(
          builtins: %{switch_to_active_on_empty_archive: true},
          archive_status: :archived,
          total_count: 3
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{action: :unarchive, kind: :row})
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.archive_status == :archived
    end

    test "does NOT switch when armed action is unrelated (e.g. :delete)" do
      state =
        build_state(
          builtins: %{switch_to_active_on_empty_archive: true},
          archive_status: :archived,
          total_count: 0
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{action: :delete, kind: :row})
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.archive_status == :archived
    end

    test "does NOT switch when rule is disabled" do
      state =
        build_state(
          builtins: %{switch_to_active_on_empty_archive: false},
          archive_status: :archived,
          total_count: 0
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{action: :unarchive, kind: :row})
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.archive_status == :archived
    end
  end

  describe "after_load/2 — switch_to_archive_on_empty_active" do
    test "switches to :archived when active empty + armed by :delete" do
      state =
        build_state(
          builtins: %{switch_to_archive_on_empty_active: true},
          archive_status: :active,
          total_count: 0
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{action: :delete, kind: :row})
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.archive_status == :archived
    end

    test "ignores :unarchive action under this rule" do
      state =
        build_state(
          builtins: %{switch_to_archive_on_empty_active: true},
          archive_status: :active,
          total_count: 0
        )

      armed_socket =
        socket()
        |> Phoenix.Component.assign(:__auto_state_armed__, %{action: :unarchive, kind: :row})
        |> Phoenix.Component.assign(:table_state, state)

      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.archive_status == :active
    end
  end

  describe "after_load/2 — reset_page_on_empty_current_page" do
    test "reloads page 1 when current page > 1 and total_count == 0" do
      state =
        build_state(
          builtins: %{reset_page_on_empty_current_page: true},
          page: 4,
          total_count: 0
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)

      # load_async assigns table_state with loading: :loading
      assert result.assigns.table_state.loading == :loading
    end

    test "does not reload when page is 1" do
      state =
        build_state(
          builtins: %{reset_page_on_empty_current_page: true},
          page: 1,
          total_count: 0
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)

      assert result.assigns.table_state.loading == :loaded
    end

    test "does not reload when total_count > 0" do
      state =
        build_state(
          builtins: %{reset_page_on_empty_current_page: true},
          page: 4,
          total_count: 5
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)
      assert result.assigns.table_state.loading == :loaded
    end
  end

  describe "after_load/2 — redirect_on_empty" do
    test "push_navigate when total_count == 0 and redirect path is a string" do
      state =
        build_state(
          builtins: %{redirect_on_empty: "/admin/dashboard"},
          total_count: 0
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)

      assert result.redirected ==
               {:live, :redirect, %{kind: :push, to: "/admin/dashboard"}} or
               match?({:live, :redirect, %{to: "/admin/dashboard"}}, result.redirected)
    end

    test "push_navigate when redirect_on_empty is a function returning a path" do
      state =
        build_state(
          builtins: %{redirect_on_empty: fn _state -> "/elsewhere" end},
          total_count: 0
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)

      assert match?({:live, :redirect, %{to: "/elsewhere"}}, result.redirected)
    end

    test "no redirect when total_count > 0" do
      state =
        build_state(
          builtins: %{redirect_on_empty: "/x"},
          total_count: 1
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)
      assert result.redirected == nil
    end

    test "no redirect when function returns non-string" do
      state =
        build_state(
          builtins: %{redirect_on_empty: fn _ -> nil end},
          total_count: 0
        )

      armed_socket = Phoenix.Component.assign(socket(), :table_state, state)
      result = AutoState.after_load(armed_socket, state)
      assert result.redirected == nil
    end
  end
end
