defmodule MishkaGervaz.Table.ComplexDslTest do
  @moduledoc """
  Tests for verifying all DSL keys through ResourceInfo.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  describe "identity section" do
    test "name is set correctly" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.identity.name == :complex_posts
    end

    test "route is set correctly" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.identity.route == "/admin/complex-posts"
    end

    test "stream_name is set correctly" do
      stream_name = ResourceInfo.stream_name(ComplexTestResource)
      assert stream_name == :complex_posts_stream
    end

    test "route accessible via TableInfo" do
      route = TableInfo.route(ComplexTestResource)
      assert route == "/admin/complex-posts"
    end
  end

  describe "source section" do
    test "actor_key is set correctly" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.actor_key == :current_user
    end

    test "master_check is a function" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.source.master_check, 1)
    end

    test "actions.read preserves developer tuple" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.actions.read == {:master_read, :tenant_read}
    end

    test "actions.get preserves developer tuple" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.actions.get == {:master_get, :read}
    end

    test "actions.destroy preserves developer tuple" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.actions.destroy == {:master_destroy, :destroy}
    end

    test "preload.always is set correctly" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.preload.always == [:author]
    end

    test "preload.master is empty when not set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.preload.master == []
    end

    test "preload.tenant is empty when not set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.preload.tenant == []
    end

    # Archive is nil for ComplexTestResource (no AshArchival and no archive section)
    test "archive is nil when resource has no AshArchival and no archive section" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.source.archive == nil
    end

    test "get_action returns appropriate action based on user type" do
      master_action = ResourceInfo.get_action(ComplexTestResource, :read, true)
      tenant_action = ResourceInfo.get_action(ComplexTestResource, :read, false)
      assert master_action == :master_read
      assert tenant_action == :tenant_read
    end

    test "all_preloads includes always preloads" do
      preloads = ResourceInfo.all_preloads(ComplexTestResource, false)
      assert :author in preloads
    end

    test "all_preloads includes always preloads for master user" do
      preloads = ResourceInfo.all_preloads(ComplexTestResource, true)
      assert :author in preloads
    end
  end

  describe "archive section with AshArchival" do
    alias MishkaGervaz.Test.Resources.ArchivableResource

    test "archive is not nil when resource has AshArchival and archive section" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive != nil
    end

    test "archive.enabled is true" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.enabled == true
    end

    test "archive.restricted is true (explicit in DSL)" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.restricted == true
    end

    test "archive.actions are tuples when AshArchival defaults are used" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.actions.read == {:master_archived, :archived}
      assert config.source.archive.actions.get == {:master_get_archived, :get_archived}
      assert config.source.archive.actions.restore == {:master_unarchive, :unarchive}

      assert config.source.archive.actions.destroy ==
               {:master_permanent_destroy, :permanent_destroy}
    end
  end

  describe "columns section" do
    test "returns all defined columns" do
      columns = ResourceInfo.columns(ComplexTestResource)
      assert length(columns) >= 6
    end

    test "column_order is set correctly" do
      order = ResourceInfo.column_order(ComplexTestResource)
      assert order == [:title, :status, :author, :view_count, :is_featured, :inserted_at]
    end

    test "title column has all expected properties" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.name == :title
      assert col.source == :title
      assert col.sortable == true
      assert col.searchable == true
      assert col.filterable == false
      assert col.visible == true
      assert col.position == :first
      assert col.export == true
      assert col.export_as == :post_title
      assert col.default == "Untitled"
      assert col.separator == " - "
      assert col.label == "Post Title"
    end

    test "title column ui properties are set correctly" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.label == "Title"
      assert col.ui.type == :text
      assert col.ui.width == "250px"
      assert col.ui.min_width == "150px"
      assert col.ui.max_width == "400px"
      assert col.ui.align == :left
      assert col.ui.class == "font-semibold"
      assert col.ui.header_class == "text-primary"
      assert col.ui.extra == %{truncate: 50}
    end

    test "status column has badge type" do
      col = ResourceInfo.column(ComplexTestResource, :status)
      assert col.ui.type == :badge
      assert is_map(col.ui.extra.colors)
    end

    test "author column has relationship source" do
      col = ResourceInfo.column(ComplexTestResource, :author)
      assert col.source == {:author, :name}
    end

    test "view_count column has number type" do
      col = ResourceInfo.column(ComplexTestResource, :view_count)
      assert col.ui.type == :number
      assert col.ui.align == :right
      assert col.ui.extra.suffix == " views"
    end

    test "is_featured column has boolean type" do
      col = ResourceInfo.column(ComplexTestResource, :is_featured)
      assert col.ui.type == :boolean
      assert col.ui.extra.true_icon == "hero-star-solid"
    end

    test "inserted_at column has datetime type" do
      col = ResourceInfo.column(ComplexTestResource, :inserted_at)
      assert col.ui.type == :datetime
      assert col.ui.extra.format == "%Y-%m-%d %H:%M"
    end

    test "type_module is resolved for each column type" do
      title_col = ResourceInfo.column(ComplexTestResource, :title)
      assert title_col.type_module == MishkaGervaz.Table.Types.Column.Text

      status_col = ResourceInfo.column(ComplexTestResource, :status)
      assert status_col.type_module == MishkaGervaz.Table.Types.Column.Badge

      view_col = ResourceInfo.column(ComplexTestResource, :view_count)
      assert view_col.type_module == MishkaGervaz.Table.Types.Column.Number

      bool_col = ResourceInfo.column(ComplexTestResource, :is_featured)
      assert bool_col.type_module == MishkaGervaz.Table.Types.Column.Boolean

      dt_col = ResourceInfo.column(ComplexTestResource, :inserted_at)
      assert dt_col.type_module == MishkaGervaz.Table.Types.Column.DateTime
    end
  end

  describe "filters section" do
    test "returns all defined filters" do
      filters = ResourceInfo.filters(ComplexTestResource)
      assert length(filters) >= 7
    end

    test "search filter has correct properties" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      assert filter.name == :search
      assert filter.type == :text
      assert filter.fields == [:title, :content]
      assert filter.visible == true
      assert filter.min_chars == 3
    end

    test "search filter ui properties are set correctly" do
      filter = ResourceInfo.filter(ComplexTestResource, :search)
      ui = get_filter_ui(filter)
      assert ui.label == "Search"
      assert ui.placeholder == "Search posts..."
      assert ui.icon == "hero-magnifying-glass"
      assert ui.debounce == 400
      assert ui.extra.autofocus == true
    end

    test "status filter has select type with options" do
      filter = ResourceInfo.filter(ComplexTestResource, :status)
      assert filter.type == :select
      assert filter.source == :status
      assert is_list(filter.options)
      assert length(filter.options) == 3
      assert filter.include_nil == "All Statuses"
    end

    test "is_featured filter has boolean type" do
      filter = ResourceInfo.filter(ComplexTestResource, :is_featured)
      assert filter.type == :boolean
      assert filter.source == :is_featured
    end

    test "view_count filter has number type with min/max" do
      filter = ResourceInfo.filter(ComplexTestResource, :view_count)
      assert filter.type == :number
      assert filter.min == 0
      assert filter.max == 1_000_000
    end

    test "published_at filter has date type" do
      filter = ResourceInfo.filter(ComplexTestResource, :published_at)
      assert filter.type == :date
    end

    test "date_range filter has date_range type" do
      filter = ResourceInfo.filter(ComplexTestResource, :date_range)
      assert filter.type == :date_range
    end

    test "author_id filter has relation type" do
      filter = ResourceInfo.filter(ComplexTestResource, :author_id)
      assert filter.type == :relation
      assert filter.display_field == :name
      assert filter.search_field == :name
      assert filter.include_nil == "No Author"
    end

    test "type_module is resolved for each filter type" do
      search = ResourceInfo.filter(ComplexTestResource, :search)
      assert search.type_module == MishkaGervaz.Table.Types.Filter.Text

      status = ResourceInfo.filter(ComplexTestResource, :status)
      assert status.type_module == MishkaGervaz.Table.Types.Filter.Select

      featured = ResourceInfo.filter(ComplexTestResource, :is_featured)
      assert featured.type_module == MishkaGervaz.Table.Types.Filter.Boolean

      views = ResourceInfo.filter(ComplexTestResource, :view_count)
      assert views.type_module == MishkaGervaz.Table.Types.Filter.Number

      date = ResourceInfo.filter(ComplexTestResource, :published_at)
      assert date.type_module == MishkaGervaz.Table.Types.Filter.Date

      date_range = ResourceInfo.filter(ComplexTestResource, :date_range)
      assert date_range.type_module == MishkaGervaz.Table.Types.Filter.DateRange

      author = ResourceInfo.filter(ComplexTestResource, :author_id)
      assert author.type_module == MishkaGervaz.Table.Types.Filter.Relation
    end

    test "filters layout is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.filters.layout.mode == :inline
      assert config.filters.layout.columns == 4
      assert config.filters.layout.collapsible == true
      assert config.filters.layout.collapsed_default == false
    end
  end

  describe "row_actions section" do
    test "returns all defined row actions" do
      actions = ResourceInfo.row_actions(ComplexTestResource)
      assert length(actions) >= 5
    end

    test "show action has correct properties" do
      action = ResourceInfo.row_action(ComplexTestResource, :show)
      assert action.name == :show
      assert action.type == :link
      assert action.path == "/admin/complex-posts/{id}"
      assert action.visible == true
      assert action.restricted == false
    end

    test "show action ui properties are set correctly" do
      action = ResourceInfo.row_action(ComplexTestResource, :show)
      ui = get_action_ui(action)
      assert ui.label == "View"
      assert ui.icon == "hero-eye"
      assert ui.class == "text-blue-600 hover:text-blue-800"
      assert ui.extra.tooltip == "View details"
    end

    test "edit action has function path" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit)
      assert action.type == :link
      assert is_function(action.path, 1)
      assert action.visible == :active
      assert action.restricted == true
    end

    test "delete action has destroy type" do
      action = ResourceInfo.row_action(ComplexTestResource, :delete)
      assert action.type == :destroy
      assert action.confirm == "Are you sure you want to delete this post?"
    end

    test "archive_action has event type with payload" do
      action = ResourceInfo.row_action(ComplexTestResource, :archive_action)
      assert action.type == :event
      assert action.event == :archive
      assert is_function(action.payload, 1)
      assert is_function(action.confirm, 1)
    end

    test "restore action visible only for archived" do
      action = ResourceInfo.row_action(ComplexTestResource, :restore)
      assert action.visible == :archived
    end

    test "type_module is resolved for each action type" do
      show = ResourceInfo.row_action(ComplexTestResource, :show)
      assert show.type_module == MishkaGervaz.Table.Types.Action.Link

      delete = ResourceInfo.row_action(ComplexTestResource, :delete)
      assert delete.type_module == MishkaGervaz.Table.Types.Action.Destroy

      archive = ResourceInfo.row_action(ComplexTestResource, :archive_action)
      assert archive.type_module == MishkaGervaz.Table.Types.Action.Event
    end

    test "row_actions layout is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      layout = config.row_actions.layout
      assert layout.position == :end
      assert layout.sticky == true
      assert layout.inline == [:show, :edit]
      assert layout.dropdown == [:more_actions]
      assert layout.auto_collapse_after == 3
    end
  end

  describe "row section" do
    test "event is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.row.event == "show"
    end

    test "selectable is enabled" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.row.selectable == true
    end

    test "class.possible is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.row.class.possible == ["bg-yellow-50", "bg-red-50", "bg-green-50"]
    end

    test "class.apply is a function" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.row.class.apply, 1)
    end
  end

  describe "bulk_actions section" do
    test "returns all defined bulk actions" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      assert length(actions) == 3
    end

    test "bulk_delete action has correct properties" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      assert action.confirm == "Delete {count} selected posts?"
      assert action.event == :bulk_delete
      assert is_function(action.payload, 1)
      assert action.restricted == true
    end

    test "bulk_delete action ui properties" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      ui = get_bulk_action_ui(action)
      assert ui.label == "Delete Selected"
      assert ui.icon == "hero-trash"
      assert ui.class == "text-red-600"
      assert ui.extra.destructive == true
    end

    test "bulk_archive action has boolean confirm" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_archive))
      assert action.confirm == true
    end

    test "bulk_publish action has no confirm" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_publish))
      assert action.confirm == false
    end

    test "bulk_actions.enabled is true" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.bulk_actions.enabled == true
    end
  end

  describe "pagination section" do
    test "pagination type is numbered" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.pagination.type == :numbered
    end

    test "page_size is 20" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.pagination.page_size == 20
    end

    test "page_size_options are set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.pagination.page_size_options == [10, 20, 50, 100]
    end

    test "load_more_label is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.pagination.ui.load_more_label == "Load More Posts"
    end

    test "loading_text is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.pagination.ui.loading_text == "Loading posts..."
    end

    test "show_total is true" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.pagination.ui.show_total == true
    end
  end

  describe "realtime section" do
    test "realtime is enabled" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.realtime.enabled == true
    end

    test "prefix is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.realtime.prefix == "complex_posts"
    end
  end

  describe "empty_state section" do
    test "message is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.message == "No posts found"
    end

    test "icon is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.icon == "hero-document-text"
    end

    test "action.label is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.action.label == "Create Post"
    end

    test "action.path is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.action.path == "/admin/complex-posts/new"
    end

    test "action.icon is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.action.icon == "hero-plus"
    end
  end

  describe "error_state section" do
    test "message is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.error_state.message == "Failed to load posts"
    end

    test "icon is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.error_state.icon == "hero-exclamation-circle"
    end

    test "retry_label is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.error_state.retry_label == "Try Again"
    end
  end

  describe "presentation section" do
    test "ui_adapter is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
    end

    test "ui_adapter_opts is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.ui_adapter_opts == []
    end

    test "theme.header_class is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.header_class == "bg-gray-100 text-gray-700"
    end

    test "theme.row_class is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.row_class == "border-b"
    end

    test "theme.border_class is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.border_class == "border-gray-200"
    end

    test "responsive.hide_on_mobile is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.responsive.hide_on_mobile == [:content, :view_count]
    end

    test "responsive.hide_on_tablet is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.responsive.hide_on_tablet == [:content]
    end

    test "responsive.mobile_layout is set" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.responsive.mobile_layout == :cards
    end

    test "features is set to specific list" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.features == [:sort, :filter, :select, :paginate]
    end

    test "features does not include bulk_actions" do
      config = ResourceInfo.table_config(ComplexTestResource)
      refute :bulk_actions in config.presentation.features
    end

    test "features does not include expand" do
      config = ResourceInfo.table_config(ComplexTestResource)
      refute :expand in config.presentation.features
    end
  end

  describe "refresh section" do
    test "refresh config is accessible" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert is_map(config)
    end

    test "enabled is true" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.enabled == true
    end

    test "interval is 30000" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.interval == 30_000
    end

    test "pause_on_interaction is true" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.pause_on_interaction == true
    end

    test "show_indicator is true" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.show_indicator == true
    end

    test "pause_on_blur is true" do
      config = ResourceInfo.refresh_config(ComplexTestResource)
      assert config.pause_on_blur == true
    end
  end

  describe "url_sync section" do
    test "url_sync config is accessible" do
      config = ResourceInfo.url_sync_config(ComplexTestResource)
      assert is_map(config)
    end

    test "enabled is true" do
      config = ResourceInfo.url_sync_config(ComplexTestResource)
      assert config.enabled == true
    end

    test "params are set correctly" do
      config = ResourceInfo.url_sync_config(ComplexTestResource)
      assert config.params == [:filters, :sort, :page, :search]
    end

    test "prefix is set" do
      config = ResourceInfo.url_sync_config(ComplexTestResource)
      assert config.prefix == "posts"
    end
  end

  describe "hooks section" do
    test "hooks are accessible" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_map(hooks)
    end

    test "on_load hook is set" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_function(hooks.on_load, 2)
    end

    test "before_delete hook is set" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_function(hooks.before_delete, 2)
    end

    test "after_delete hook is set" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_function(hooks.after_delete, 2)
    end

    test "on_filter hook is set" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_function(hooks.on_filter, 2)
    end

    test "on_select hook is set" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_function(hooks.on_select, 2)
    end

    test "on_sort hook is set" do
      hooks = ResourceInfo.hooks(ComplexTestResource)
      assert is_function(hooks.on_sort, 2)
    end
  end

  describe "full config structure" do
    test "config has all top-level sections" do
      config = ResourceInfo.table_config(ComplexTestResource)

      assert Map.has_key?(config, :identity)
      assert Map.has_key?(config, :source)
      assert Map.has_key?(config, :columns)
      assert Map.has_key?(config, :filters)
      assert Map.has_key?(config, :row_actions)
      assert Map.has_key?(config, :bulk_actions)
      assert Map.has_key?(config, :row)
      assert Map.has_key?(config, :pagination)
      assert Map.has_key?(config, :realtime)
      assert Map.has_key?(config, :empty_state)
      assert Map.has_key?(config, :error_state)
      assert Map.has_key?(config, :presentation)
      assert Map.has_key?(config, :refresh)
      assert Map.has_key?(config, :url_sync)
      assert Map.has_key?(config, :hooks)
      assert Map.has_key?(config, :column_order)
      assert Map.has_key?(config, :detected_preloads)
    end

    test "detected_preloads contains author from relationship column" do
      preloads = ResourceInfo.detected_preloads(ComplexTestResource)
      assert :author in preloads
    end
  end

  # Helper functions to extract UI from entities (handles list vs struct)
  defp get_filter_ui(%{ui: [ui | _]}), do: ui
  defp get_filter_ui(%{ui: ui}) when is_struct(ui), do: ui
  defp get_filter_ui(_), do: nil

  defp get_action_ui(%{ui: [ui | _]}), do: ui
  defp get_action_ui(%{ui: ui}) when is_struct(ui), do: ui
  defp get_action_ui(_), do: nil

  defp get_bulk_action_ui(%{ui: [ui | _]}), do: ui
  defp get_bulk_action_ui(%{ui: ui}) when is_struct(ui), do: ui
  defp get_bulk_action_ui(_), do: nil
end
