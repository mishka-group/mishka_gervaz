defmodule MishkaGervaz.Table.Web.BulkActionHandlerTest do
  @moduledoc """
  Tests for the bulk action handler, specifically tenant context handling
  in build_bulk_query.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Events.BulkActionHandler
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.State.Static
  alias MishkaGervaz.Resource.Info.Table, as: Info

  describe "build_bulk_query tenant context" do
    test "tenant user query includes tenant" do
      state = build_table_state(master_user?: false, site_id: "site-123")
      resource = state.static.resource

      query = BulkActionHandler.Default.build_bulk_query(resource, state, nil)

      assert query.tenant == "site-123"
    end

    test "master user query has no tenant" do
      state = build_table_state(master_user?: true, site_id: nil)
      resource = state.static.resource

      query = BulkActionHandler.Default.build_bulk_query(resource, state, nil)

      assert is_nil(query.tenant)
    end

    test "tenant user query with exclude filter includes tenant" do
      state = build_table_state(master_user?: false, site_id: "site-456")
      resource = state.static.resource

      query =
        BulkActionHandler.Default.build_bulk_query(
          resource,
          state,
          {:exclude, ["id-1", "id-2"]}
        )

      assert query.tenant == "site-456"
    end

    test "master user query with exclude filter has no tenant" do
      state = build_table_state(master_user?: true, site_id: nil)
      resource = state.static.resource

      query =
        BulkActionHandler.Default.build_bulk_query(
          resource,
          state,
          {:exclude, ["id-1"]}
        )

      assert is_nil(query.tenant)
    end

    test "tenant from current_user site_id is used" do
      state = build_table_state(master_user?: false, site_id: "tenant-abc")
      resource = state.static.resource

      query = BulkActionHandler.Default.build_bulk_query(resource, state, nil)

      assert query.tenant == "tenant-abc"
      assert query.action.name in [:tenant_read, :read]
    end
  end

  defp build_table_state(opts) do
    master_user? = Keyword.get(opts, :master_user?, false)
    site_id = Keyword.get(opts, :site_id)
    archive_status = Keyword.get(opts, :archive_status, :active)

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
      filter_layout: :inline,
      pagination_ui: :simple,
      theme: nil,
      sortable_columns: [],
      sort_field_map: %{},
      hooks: %{},
      url_sync_config: nil,
      page_size: 20
    }

    current_user =
      if site_id do
        %{id: "user-1", site_id: site_id, role: :admin}
      else
        %{id: "user-1", site_id: nil, role: :admin}
      end

    %State{
      static: static,
      current_user: current_user,
      master_user?: master_user?,
      preload_aliases: %{},
      supports_archive: false,
      template: MishkaGervaz.Table.Templates.Standard,
      loading: :loaded,
      loading_type: :full,
      has_initial_data?: true,
      records_result: nil,
      page: 1,
      has_more?: false,
      total_count: 0,
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
      base_path: "/test",
      preserved_params: %{},
      saved_active_state: nil,
      saved_archived_state: nil
    }
  end
end
