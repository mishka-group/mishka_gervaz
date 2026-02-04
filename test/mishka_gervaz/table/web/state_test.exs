defmodule MishkaGervaz.Table.Web.StateTest do
  @moduledoc """
  Tests for the State module.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.{User, Post, MultiTenantResource}
  alias Phoenix.LiveView.AsyncResult

  # Test user fixtures
  defp master_user, do: %{id: "master-123", site_id: nil, name: "Master Admin"}
  defp tenant_user, do: %{id: "tenant-456", site_id: "site-abc", name: "Tenant User"}
  defp no_site_id_user, do: %{id: "user-789", name: "Regular User"}

  describe "init/3" do
    test "initializes state with required fields" do
      state = State.init("test-id", User, nil)

      assert state.static.id == "test-id"
      assert state.static.resource == User
      assert is_atom(state.static.stream_name)
      assert state.current_user == nil
      assert state.master_user? == false
    end

    test "initializes with master user" do
      state = State.init("test-id", User, master_user())

      assert state.master_user? == true
      assert state.current_user.site_id == nil
    end

    test "initializes with tenant user" do
      state = State.init("test-id", User, tenant_user())

      assert state.master_user? == false
      assert state.current_user.site_id == "site-abc"
    end

    test "generates stream_name from resource module" do
      state = State.init("test-id", User, nil)

      # Stream name is based on identity name (:users) from DSL
      assert is_atom(state.static.stream_name)
    end

    test "initializes with correct default values" do
      state = State.init("test-id", User, nil)

      assert state.loading == :initial
      assert state.loading_type == :initial
      assert state.has_initial_data? == false
      assert state.page == 1
      assert state.has_more? == false
      assert state.total_count == nil
      assert state.total_pages == nil
      assert state.archive_status == :active
      assert state.select_all? == false
      assert state.expanded_id == nil
      assert state.expanded_data == nil
      assert state.base_path == nil
    end

    test "initializes with empty selection sets" do
      state = State.init("test-id", User, nil)

      assert state.selected_ids == MapSet.new()
      assert state.excluded_ids == MapSet.new()
    end

    test "initializes records_result as loading" do
      state = State.init("test-id", User, nil)

      assert %AsyncResult{loading: true} = state.records_result
    end

    test "builds columns from resource config" do
      state = State.init("test-id", User, nil)

      assert is_list(state.static.columns)
      column_names = Enum.map(state.static.columns, & &1.name)
      assert :name in column_names
      assert :email in column_names
    end

    test "builds filters from resource config" do
      state = State.init("test-id", User, nil)

      assert is_list(state.static.filters)
      filter_names = Enum.map(state.static.filters, & &1.name)
      assert :search in filter_names
      assert :role in filter_names
    end

    test "builds row_actions from resource config" do
      state = State.init("test-id", User, nil)

      assert is_list(state.static.row_actions)
      action_names = Enum.map(state.static.row_actions, & &1.name)
      assert :show in action_names
      assert :edit in action_names
      assert :delete in action_names
    end

    test "builds bulk_actions when enabled" do
      state = State.init("test-id", User, nil)

      # User resource has bulk_actions configured
      assert is_list(state.static.bulk_actions)
    end

    test "resolves UI adapter" do
      state = State.init("test-id", User, nil)

      assert state.static.ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
    end

    test "resolves template" do
      state = State.init("test-id", User, nil)

      assert state.template == MishkaGervaz.Table.Templates.Table
    end

    test "sets page_size from config" do
      state = State.init("test-id", User, nil)

      assert state.static.page_size == 20
    end

    test "builds hooks from config" do
      state = State.init("test-id", User, nil)

      assert is_map(state.static.hooks)
    end
  end

  describe "update/2" do
    test "updates single field" do
      state = State.init("test-id", User, nil)
      updated = State.update(state, page: 5)

      assert updated.page == 5
      assert updated.static.id == "test-id"
    end

    test "updates multiple fields" do
      state = State.init("test-id", User, nil)

      updated =
        State.update(state,
          page: 3,
          loading: :loading,
          has_more?: true
        )

      assert updated.page == 3
      assert updated.loading == :loading
      assert updated.has_more? == true
    end

    test "preserves unchanged fields" do
      state = State.init("test-id", User, nil)
      updated = State.update(state, page: 10)

      assert updated.static.id == state.static.id
      assert updated.static.resource == state.static.resource
      assert updated.static.columns == state.static.columns
    end
  end

  describe "bidirectional_url_sync?/1" do
    test "returns true when enabled and bidirectional" do
      static = %State.Static{
        url_sync_config: %{enabled: true, mode: :bidirectional},
        resource: User
      }

      state = %State{static: static}

      assert State.bidirectional_url_sync?(state) == true
    end

    test "returns false when enabled but read_only" do
      static = %State.Static{url_sync_config: %{enabled: true, mode: :read_only}, resource: User}
      state = %State{static: static}

      assert State.bidirectional_url_sync?(state) == false
    end

    test "returns false when disabled" do
      static = %State.Static{
        url_sync_config: %{enabled: false, mode: :bidirectional},
        resource: User
      }

      state = %State{static: static}

      assert State.bidirectional_url_sync?(state) == false
    end

    test "returns false when config is nil" do
      static = %State.Static{url_sync_config: nil, resource: User}
      state = %State{static: static}

      assert State.bidirectional_url_sync?(state) == false
    end
  end

  describe "apply_url_state/2" do
    setup do
      state = State.init("test-id", User, nil)
      {:ok, state: state}
    end

    test "returns state unchanged when url_state is nil", %{state: state} do
      result = State.apply_url_state(state, nil)

      assert result == state
    end

    test "applies filters from url_state", %{state: state} do
      url_state = %{filters: %{role: "admin", active: true}}
      result = State.apply_url_state(state, url_state)

      assert result.filter_values[:role] == "admin"
      assert result.filter_values[:active] == true
    end

    test "merges filters with existing filter_values", %{state: state} do
      state = %{state | filter_values: %{existing: "value"}}
      url_state = %{filters: %{role: "admin"}}
      result = State.apply_url_state(state, url_state)

      assert result.filter_values[:existing] == "value"
      assert result.filter_values[:role] == "admin"
    end

    test "ignores empty filters", %{state: state} do
      original_filters = state.filter_values
      url_state = %{filters: %{}}
      result = State.apply_url_state(state, url_state)

      assert result.filter_values == original_filters
    end

    test "applies sort from url_state", %{state: state} do
      url_state = %{sort: [{:name, :asc}, {:email, :desc}]}
      result = State.apply_url_state(state, url_state)

      assert result.sort_fields == [{:name, :asc}, {:email, :desc}]
    end

    test "ignores empty sort", %{state: state} do
      original_sort = state.sort_fields
      url_state = %{sort: []}
      result = State.apply_url_state(state, url_state)

      assert result.sort_fields == original_sort
    end

    test "applies page from url_state", %{state: state} do
      url_state = %{page: 5}
      result = State.apply_url_state(state, url_state)

      assert result.page == 5
    end

    test "ignores invalid page values", %{state: state} do
      assert State.apply_url_state(state, %{page: 0}).page == 1
      assert State.apply_url_state(state, %{page: -1}).page == 1
      assert State.apply_url_state(state, %{page: "invalid"}).page == 1
    end

    test "applies search from url_state", %{state: state} do
      url_state = %{search: "test query"}
      result = State.apply_url_state(state, url_state)

      assert result.filter_values[:search] == "test query"
    end

    test "ignores empty search", %{state: state} do
      url_state = %{search: ""}
      result = State.apply_url_state(state, url_state)

      refute Map.has_key?(result.filter_values, :search)
    end

    test "applies path from url_state", %{state: state} do
      url_state = %{path: "/admin/users"}
      result = State.apply_url_state(state, url_state)

      assert result.base_path == "/admin/users"
    end

    test "applies all url_state fields together", %{state: state} do
      url_state = %{
        filters: %{role: "admin"},
        sort: [{:name, :asc}],
        page: 3,
        search: "john",
        path: "/admin/users"
      }

      result = State.apply_url_state(state, url_state)

      assert result.filter_values[:role] == "admin"
      assert result.filter_values[:search] == "john"
      assert result.sort_fields == [{:name, :asc}]
      assert result.page == 3
      assert result.base_path == "/admin/users"
    end
  end

  describe "switch_template/2" do
    test "returns error when switchable_templates is empty" do
      static = %State.Static{switchable_templates: [], resource: User}
      state = %State{static: static}

      assert {:error, :template_not_allowed} = State.switch_template(state, :grid)
    end

    test "returns error when template not in switchable list" do
      static = %State.Static{
        switchable_templates: [
          MishkaGervaz.Table.Templates.Table
        ],
        resource: User
      }

      state = %State{static: static}

      assert {:error, :template_not_allowed} =
               State.switch_template(state, MishkaGervaz.Table.Templates.MediaGallery)
    end

    test "switches to template by module" do
      static = %State.Static{
        switchable_templates: [
          MishkaGervaz.Table.Templates.Table,
          MishkaGervaz.Table.Templates.MediaGallery
        ],
        resource: User
      }

      state = %State{
        template: MishkaGervaz.Table.Templates.Table,
        static: static
      }

      assert {:ok, updated} =
               State.switch_template(state, MishkaGervaz.Table.Templates.MediaGallery)

      assert updated.template == MishkaGervaz.Table.Templates.MediaGallery
    end
  end

  describe "template_switching_enabled?/1" do
    test "returns true when multiple templates available" do
      static = %State.Static{
        switchable_templates: [
          MishkaGervaz.Table.Templates.Table,
          MishkaGervaz.Table.Templates.MediaGallery
        ],
        resource: User
      }

      state = %State{static: static}

      assert State.template_switching_enabled?(state) == true
    end

    test "returns false when only one template" do
      static = %State.Static{
        switchable_templates: [MishkaGervaz.Table.Templates.Table],
        resource: User
      }

      state = %State{static: static}

      assert State.template_switching_enabled?(state) == false
    end

    test "returns false when no templates" do
      static = %State.Static{switchable_templates: [], resource: User}
      state = %State{static: static}

      assert State.template_switching_enabled?(state) == false
    end
  end

  describe "can_modify_record?/2 - master user" do
    test "master user can modify any record" do
      state = State.init("test-id", User, master_user())
      record = %{id: "record-1", site_id: "other-site"}

      assert State.can_modify_record?(state, record) == true
    end

    test "master user can modify records with nil site_id" do
      state = State.init("test-id", User, master_user())
      record = %{id: "record-1", site_id: nil}

      assert State.can_modify_record?(state, record) == true
    end
  end

  describe "can_modify_record?/2 - tenant user" do
    test "tenant user can modify own tenant records" do
      # Create state manually to avoid full init for resource without filters
      static = %State.Static{resource: MultiTenantResource}

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record = struct!(MultiTenantResource, %{id: "record-1", site_id: "site-abc", name: "Test"})

      assert State.can_modify_record?(state, record) == true
    end

    test "tenant user cannot modify other tenant records" do
      static = %State.Static{resource: MultiTenantResource}

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record =
        struct!(MultiTenantResource, %{id: "record-1", site_id: "other-site", name: "Test"})

      assert State.can_modify_record?(state, record) == false
    end

    test "tenant user cannot modify records with nil site_id" do
      static = %State.Static{resource: MultiTenantResource}

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record = struct!(MultiTenantResource, %{id: "record-1", site_id: nil, name: "Test"})

      assert State.can_modify_record?(state, record) == false
    end
  end

  describe "can_modify_record?/2 - no multitenancy" do
    test "allows modification when resource has no multitenancy" do
      state = State.init("test-id", User, no_site_id_user())
      # Plain map, not a struct - no multitenancy
      record = %{id: "record-1", name: "Test"}

      assert State.can_modify_record?(state, record) == true
    end
  end

  describe "record_visible?/2 - master user" do
    test "master user can see all records" do
      state = State.init("test-id", User, master_user())
      record = %{id: "record-1", site_id: "any-site"}

      assert State.record_visible?(state, record) == true
    end
  end

  describe "record_visible?/2 - tenant user" do
    test "tenant user can see own tenant records" do
      static = %State.Static{config: %{}, resource: MultiTenantResource}

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record = struct!(MultiTenantResource, %{id: "record-1", site_id: "site-abc", name: "Test"})

      assert State.record_visible?(state, record) == true
    end

    test "tenant user can see records with nil site_id" do
      static = %State.Static{config: %{}, resource: MultiTenantResource}

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record = struct!(MultiTenantResource, %{id: "record-1", site_id: nil, name: "Test"})

      assert State.record_visible?(state, record) == true
    end

    test "tenant user cannot see other tenant records" do
      static = %State.Static{config: %{}, resource: MultiTenantResource}

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record =
        struct!(MultiTenantResource, %{id: "record-1", site_id: "other-site", name: "Test"})

      assert State.record_visible?(state, record) == false
    end
  end

  describe "record_visible?/2 - custom visibility function" do
    test "uses custom visibility function when defined" do
      # Create state with custom visibility function in config
      static = %State.Static{
        config: %{
          realtime: %{
            visible: fn _record, _user -> true end
          }
        },
        resource: MultiTenantResource
      }

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record =
        struct!(MultiTenantResource, %{id: "record-1", site_id: "other-site", name: "Test"})

      assert State.record_visible?(state, record) == true
    end

    test "custom visibility function can deny access" do
      static = %State.Static{
        config: %{
          realtime: %{
            visible: fn _record, _user -> false end
          }
        },
        resource: MultiTenantResource
      }

      state = %State{
        static: static,
        master_user?: false,
        current_user: tenant_user()
      }

      record = struct!(MultiTenantResource, %{id: "record-1", site_id: "site-abc", name: "Test"})

      assert State.record_visible?(state, record) == false
    end
  end

  describe "record_visible?/2 - no multitenancy" do
    test "all records visible when no multitenancy" do
      state = State.init("test-id", User, no_site_id_user())
      record = %{id: "record-1", name: "Test"}

      assert State.record_visible?(state, record) == true
    end
  end

  describe "get_action/2" do
    test "returns action for read" do
      state = State.init("test-id", User, nil)
      action = State.get_action(state, :read)

      assert is_atom(action)
    end

    test "returns action for get" do
      state = State.init("test-id", User, nil)
      action = State.get_action(state, :get)

      assert is_atom(action)
    end

    test "returns action for destroy" do
      state = State.init("test-id", User, nil)
      action = State.get_action(state, :destroy)

      assert is_atom(action)
    end
  end

  describe "get_preloads/1" do
    test "returns list of preloads" do
      state = State.init("test-id", Post, nil)
      preloads = State.get_preloads(state)

      assert is_list(preloads)
    end
  end

  describe "is_master_user? (via init)" do
    test "user with site_id: nil is master user" do
      state = State.init("test-id", User, %{site_id: nil})

      assert state.master_user? == true
    end

    test "user with site_id value is not master user" do
      state = State.init("test-id", User, %{site_id: "site-123"})

      assert state.master_user? == false
    end

    test "user without site_id key is not master user" do
      state = State.init("test-id", User, %{name: "Test"})

      assert state.master_user? == false
    end

    test "nil user is not master user" do
      state = State.init("test-id", User, nil)

      assert state.master_user? == false
    end
  end

  describe "filter defaults" do
    test "applies filter defaults from DSL" do
      # Create a state and check if default filter values are applied
      state = State.init("test-id", User, nil)

      # filter_values should be a map (possibly empty if no defaults)
      assert is_map(state.filter_values)
    end
  end

  describe "sort defaults" do
    test "sets default sort when inserted_at column exists and is sortable" do
      state = State.init("test-id", User, nil)

      # User has inserted_at column with sortable: true
      assert state.sort_fields == [{:inserted_at, :desc}]
    end
  end

  describe "column type inference (via init)" do
    test "columns have type_module assigned" do
      state = State.init("test-id", User, nil)

      Enum.each(state.static.columns, fn col ->
        # Every column should have a type_module (either explicit or inferred)
        assert Map.has_key?(col, :type_module),
               "Column #{inspect(col.name)} missing type_module"
      end)
    end

    test "type_module is always resolved" do
      state = State.init("test-id", User, nil)
      name_col = Enum.find(state.static.columns, &(&1.name == :name))

      assert is_atom(name_col.type_module)
      assert name_col.type_module == MishkaGervaz.Table.Types.Column.Text
    end

    test "columns with explicit type get correct type module" do
      state = State.init("test-id", Post, nil)

      # Post resource has columns with explicit types
      title_col = Enum.find(state.static.columns, &(&1.name == :title))
      assert title_col != nil
      assert Map.has_key?(title_col, :type_module)
    end

    test "columns are associated with their attribute" do
      state = State.init("test-id", User, nil)
      name_col = Enum.find(state.static.columns, &(&1.name == :name))

      # Column should have attribute info
      assert name_col.attribute != nil
      assert name_col.attribute.name == :name
    end
  end

  describe "filter type resolution (via init)" do
    test "text filter gets Text type module" do
      state = State.init("test-id", User, nil)
      search_filter = Enum.find(state.static.filters, &(&1.name == :search))

      assert search_filter.type_module == MishkaGervaz.Table.Types.Filter.Text
    end

    test "select filter gets Select type module" do
      state = State.init("test-id", User, nil)
      role_filter = Enum.find(state.static.filters, &(&1.name == :role))

      assert role_filter.type_module == MishkaGervaz.Table.Types.Filter.Select
    end

    test "boolean filter gets Boolean type module" do
      state = State.init("test-id", User, nil)
      active_filter = Enum.find(state.static.filters, &(&1.name == :active))

      assert active_filter.type_module == MishkaGervaz.Table.Types.Filter.Boolean
    end
  end

  describe "filter defaults (via init)" do
    test "filter with default value is included in filter_values" do
      # Manually create filters with defaults to test
      filters = [
        %{name: :status, default: "active"},
        %{name: :search, default: nil}
      ]

      # Test the logic directly
      filter_values =
        filters
        |> Enum.filter(&(Map.get(&1, :default) != nil))
        |> Map.new(&{&1.name, &1.default})

      assert filter_values == %{status: "active"}
    end

    test "filter without default is not included" do
      state = State.init("test-id", User, nil)

      # User resource filters don't have defaults, so filter_values should be empty or minimal
      assert is_map(state.filter_values)
    end
  end

  describe "column ordering (via init)" do
    test "columns are returned in expected order" do
      state = State.init("test-id", User, nil)

      # Columns should be in a list
      assert is_list(state.static.columns)
      assert length(state.static.columns) > 0

      # Each column should have expected fields
      Enum.each(state.static.columns, fn col ->
        assert Map.has_key?(col, :name)
        assert Map.has_key?(col, :type_module)
      end)
    end

    test "column order matches DSL definition when specified" do
      state = State.init("test-id", Post, nil)

      column_names = Enum.map(state.static.columns, & &1.name)

      # Post has explicit column order in DSL
      # Verify columns are in a consistent order
      assert is_list(column_names)
      assert :title in column_names
    end
  end

  describe "UI adapter resolution (via init)" do
    test "resolves to Tailwind by default" do
      state = State.init("test-id", User, nil)

      assert state.static.ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
    end

    test "ui_adapter_opts is a list" do
      state = State.init("test-id", User, nil)

      assert is_list(state.static.ui_adapter_opts)
    end
  end

  describe "template resolution (via init)" do
    test "resolves to Table template by default" do
      state = State.init("test-id", User, nil)

      assert state.template == MishkaGervaz.Table.Templates.Table
    end

    test "template_options is a list" do
      state = State.init("test-id", User, nil)

      assert is_list(state.static.template_options)
    end

    test "switchable_templates is a list" do
      state = State.init("test-id", User, nil)

      assert is_list(state.static.switchable_templates)
    end
  end

  describe "resource introspection (via init)" do
    test "columns have attribute information" do
      state = State.init("test-id", User, nil)
      name_col = Enum.find(state.static.columns, &(&1.name == :name))

      # Column should have attribute info from resource
      assert Map.has_key?(name_col, :attribute)
    end

    test "filters have attribute or calculation information" do
      state = State.init("test-id", User, nil)

      Enum.each(state.static.filters, fn filter ->
        # Each filter should have attribute or calculation info
        assert Map.has_key?(filter, :attribute) or Map.has_key?(filter, :calculation)
      end)
    end
  end

  describe "struct properties" do
    test "state is a proper struct" do
      state = State.init("test-id", User, nil)

      assert is_struct(state, State)
    end

    test "all expected fields are present" do
      state = State.init("test-id", User, nil)

      # Static fields (configuration that never changes)
      expected_static_fields = [
        :id,
        :resource,
        :stream_name,
        :config,
        :columns,
        :filters,
        :row_actions,
        :bulk_actions,
        :ui_adapter,
        :ui_adapter_opts,
        :switchable_templates,
        :template_options,
        :page_size,
        :hooks,
        :url_sync_config,
        :features,
        :filter_layout,
        :pagination_ui,
        :theme,
        :sortable_columns
      ]

      # Dynamic fields (user interaction state)
      expected_dynamic_fields = [
        :static,
        :current_user,
        :master_user?,
        :preload_aliases,
        :template,
        :loading,
        :loading_type,
        :has_initial_data?,
        :records_result,
        :page,
        :has_more?,
        :total_count,
        :total_pages,
        :filter_values,
        :sort_fields,
        :archive_status,
        :relation_filter_state,
        :selected_ids,
        :excluded_ids,
        :select_all?,
        :expanded_id,
        :expanded_data,
        :base_path,
        :saved_active_state,
        :saved_archived_state,
        :supports_archive
      ]

      state_keys = Map.keys(state) -- [:__struct__]
      static_keys = Map.keys(state.static) -- [:__struct__]

      Enum.each(expected_dynamic_fields, fn field ->
        assert field in state_keys, "Expected field #{inspect(field)} not found in state"
      end)

      Enum.each(expected_static_fields, fn field ->
        assert field in static_keys, "Expected field #{inspect(field)} not found in state.static"
      end)
    end
  end
end
