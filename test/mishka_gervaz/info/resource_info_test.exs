defmodule MishkaGervaz.Info.ResourceInfoTest do
  @moduledoc """
  Tests for the ResourceInfo introspection module with strict value assertions.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo

  alias MishkaGervaz.Test.Resources.{
    Post,
    User,
    Comment,
    MinimalResource,
    DslOverrideResource
  }

  # table_config/1

  describe "table_config/1" do
    test "Post config has all expected top-level keys" do
      config = ResourceInfo.table_config(Post)

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

    test "Post identity section has correct values" do
      config = ResourceInfo.table_config(Post)

      assert config.identity.name == :posts
      assert config.identity.route == "/admin/posts"
      assert config.identity.stream_name == :posts_stream
    end

    test "User identity section has correct values" do
      config = ResourceInfo.table_config(User)

      assert config.identity.name == :users
      assert config.identity.route == "/admin/users"
    end

    test "Comment identity section has correct values" do
      config = ResourceInfo.table_config(Comment)

      assert config.identity.name == :comments
      assert config.identity.route == "/admin/comments"
    end
  end

  # columns/1 and column/2

  describe "columns/1" do
    test "Post returns exactly 6 columns" do
      columns = ResourceInfo.columns(Post)

      assert length(columns) == 6
    end

    test "Post column names are correct" do
      columns = ResourceInfo.columns(Post)
      column_names = Enum.map(columns, & &1.name)

      assert :title in column_names
      assert :status in column_names
      assert :user in column_names
      assert :view_count in column_names
      assert :inserted_at in column_names
      assert :view_count_formatted in column_names
    end

    test "User returns exactly 5 columns" do
      columns = ResourceInfo.columns(User)

      assert length(columns) == 5
    end

    test "User column names are correct" do
      columns = ResourceInfo.columns(User)
      column_names = Enum.map(columns, & &1.name)

      assert :name in column_names
      assert :email in column_names
      assert :role in column_names
      assert :active in column_names
      assert :inserted_at in column_names
    end

    test "Comment returns exactly 5 columns" do
      columns = ResourceInfo.columns(Comment)

      assert length(columns) == 5
    end
  end

  describe "column/2" do
    test "Post :title column has correct properties" do
      col = ResourceInfo.column(Post, :title)

      assert col.name == :title
      assert col.sortable == true
      assert col.searchable == true
      assert col.ui.label == "Title"
      assert col.ui.class == "font-semibold"
    end

    test "Post :status column has badge type" do
      col = ResourceInfo.column(Post, :status)

      assert col.name == :status
      assert col.sortable == true
      assert col.ui.label == "Status"
      assert col.ui.type == :badge
    end

    test "Post :user column has relationship source" do
      col = ResourceInfo.column(Post, :user)

      assert col.name == :user
      assert col.source == [:user, :name]
      assert col.sortable == false
      assert col.ui.label == "Author"
    end

    test "Post :view_count column has number type" do
      col = ResourceInfo.column(Post, :view_count)

      assert col.name == :view_count
      assert col.sortable == true
      assert col.ui.label == "Views"
      assert col.ui.type == :number
    end

    test "Post :inserted_at column has datetime type" do
      col = ResourceInfo.column(Post, :inserted_at)

      assert col.name == :inserted_at
      assert col.sortable == true
      assert col.ui.label == "Created"
      assert col.ui.type == :datetime
    end

    test "User :name column has correct properties" do
      col = ResourceInfo.column(User, :name)

      assert col.name == :name
      assert col.sortable == true
      assert col.searchable == true
      assert col.ui.label == "Full Name"
    end

    test "User :role column has badge type" do
      col = ResourceInfo.column(User, :role)

      assert col.name == :role
      assert col.sortable == true
      assert col.ui.label == "User Role"
      assert col.ui.type == :badge
    end

    test "returns nil for non-existent column" do
      col = ResourceInfo.column(Post, :non_existent)

      assert col == nil
    end
  end

  describe "column_order/1" do
    test "Post column_order matches exact definition order" do
      order = ResourceInfo.column_order(Post)

      assert order == [:title, :status, :user, :view_count, :inserted_at, :view_count_formatted]
    end
  end

  # filters/1 and filter/2

  describe "filters/1" do
    test "Post returns exactly 3 filters" do
      filters = ResourceInfo.filters(Post)

      assert length(filters) == 3
    end

    test "Post filter names are correct" do
      filters = ResourceInfo.filters(Post)
      filter_names = Enum.map(filters, & &1.name)

      assert :search in filter_names
      assert :status in filter_names
      assert :user_id in filter_names
    end

    test "User returns exactly 3 filters" do
      filters = ResourceInfo.filters(User)

      assert length(filters) == 3
    end

    test "Comment returns exactly 3 filters" do
      filters = ResourceInfo.filters(Comment)

      assert length(filters) == 3
    end
  end

  describe "filter/2" do
    test "Post :search filter has correct properties" do
      filter = ResourceInfo.filter(Post, :search)

      assert filter.name == :search
      assert filter.type == :text
      assert filter.fields == [:title, :content]
      assert filter.type_module == MishkaGervaz.Table.Types.Filter.Text
    end

    test "Post :status filter has select type" do
      filter = ResourceInfo.filter(Post, :status)

      assert filter.name == :status
      assert filter.type == :select
      assert length(filter.options) == 3
      assert filter.type_module == MishkaGervaz.Table.Types.Filter.Select
    end

    test "Post :user_id filter has relation type" do
      filter = ResourceInfo.filter(Post, :user_id)

      assert filter.name == :user_id
      assert filter.type == :relation
      assert filter.resource == MishkaGervaz.Test.Resources.User
      assert filter.display_field == :name
      assert filter.type_module == MishkaGervaz.Table.Types.Filter.Relation
    end

    test "User :search filter has correct fields" do
      filter = ResourceInfo.filter(User, :search)

      assert filter.name == :search
      assert filter.type == :text
      assert filter.fields == [:name, :email]
    end

    test "User :active filter has boolean type" do
      filter = ResourceInfo.filter(User, :active)

      assert filter.name == :active
      assert filter.type == :boolean
      assert filter.type_module == MishkaGervaz.Table.Types.Filter.Boolean
    end

    test "Comment :user_id filter depends on :post_id" do
      filter = ResourceInfo.filter(Comment, :user_id)

      assert filter.name == :user_id
      assert filter.depends_on == :post_id
    end

    test "returns nil for non-existent filter" do
      filter = ResourceInfo.filter(Post, :non_existent)

      assert filter == nil
    end
  end

  # row_actions/1 and row_action/2

  describe "row_actions/1" do
    test "Post returns exactly 6 row actions" do
      actions = ResourceInfo.row_actions(Post)

      assert length(actions) == 6
    end

    test "Post action names are correct" do
      actions = ResourceInfo.row_actions(Post)
      action_names = Enum.map(actions, & &1.name)

      assert :show in action_names
      assert :edit in action_names
      assert :publish in action_names
      assert :delete in action_names
    end

    test "User returns exactly 3 row actions" do
      actions = ResourceInfo.row_actions(User)

      assert length(actions) == 3
    end

    test "Comment returns exactly 2 row actions" do
      actions = ResourceInfo.row_actions(Comment)

      assert length(actions) == 2
    end
  end

  describe "row_action/2" do
    test "Post :show action has link type" do
      action = ResourceInfo.row_action(Post, :show)

      assert action.name == :show
      assert action.type == :link
      assert is_function(action.path, 1)
      assert action.type_module == MishkaGervaz.Table.Types.Action.Link
    end

    test "Post :edit action has link type" do
      action = ResourceInfo.row_action(Post, :edit)

      assert action.name == :edit
      assert action.type == :link
      assert is_function(action.path, 1)
    end

    test "Post :publish action has event type with correct event name" do
      action = ResourceInfo.row_action(Post, :publish)

      assert action.name == :publish
      assert action.type == :event
      assert action.event == "publish_post"
      assert is_function(action.visible, 2)
      # ui is a list of UI structs
      assert hd(action.ui).label == "Publish"
      assert hd(action.ui).icon == "hero-rocket-launch"
      assert action.type_module == MishkaGervaz.Table.Types.Action.Event
    end

    test "Post :delete action has destroy type with confirm message" do
      action = ResourceInfo.row_action(Post, :delete)

      assert action.name == :delete
      assert action.type == :destroy
      assert action.confirm == "Are you sure you want to delete this post?"
      assert action.type_module == MishkaGervaz.Table.Types.Action.Destroy
    end

    test "User :show action has correct UI properties" do
      action = ResourceInfo.row_action(User, :show)

      assert action.name == :show
      # ui is a list of UI structs
      assert hd(action.ui).label == "View"
      assert hd(action.ui).icon == "hero-eye"
    end

    test "User :delete action has confirm message" do
      action = ResourceInfo.row_action(User, :delete)

      assert action.name == :delete
      assert action.confirm == "Are you sure you want to delete this user?"
    end

    test "Comment :approve action has correct event" do
      action = ResourceInfo.row_action(Comment, :approve)

      assert action.name == :approve
      assert action.type == :event
      assert action.event == "approve_comment"
      # ui is a list of UI structs
      assert hd(action.ui).label == "Approve"
      assert hd(action.ui).icon == "hero-check"
    end

    test "returns nil for non-existent action" do
      action = ResourceInfo.row_action(Post, :non_existent)

      assert action == nil
    end
  end

  # bulk_actions/1

  describe "bulk_actions/1" do
    test "Post returns exactly 1 bulk action" do
      actions = ResourceInfo.bulk_actions(Post)

      assert length(actions) == 1
    end

    test "Post bulk :delete action has correct confirm message" do
      actions = ResourceInfo.bulk_actions(Post)
      delete_action = Enum.find(actions, &(&1.name == :delete))

      assert delete_action.name == :delete
      assert delete_action.confirm == "Delete selected posts?"
    end

    test "User returns exactly 1 bulk action" do
      actions = ResourceInfo.bulk_actions(User)

      assert length(actions) == 1
    end

    test "User bulk :delete action has correct confirm message" do
      actions = ResourceInfo.bulk_actions(User)
      delete_action = Enum.find(actions, &(&1.name == :delete))

      assert delete_action.confirm == "Delete selected users?"
    end
  end

  # get_action/3

  describe "get_action/3" do
    test "Post read action uses developer-configured tuple" do
      master_action = ResourceInfo.get_action(Post, :read, true)
      tenant_action = ResourceInfo.get_action(Post, :read, false)

      assert master_action == :master_read
      assert tenant_action == :tenant_read
    end

    test "Post destroy action uses developer-configured tuple" do
      master_action = ResourceInfo.get_action(Post, :destroy, true)
      tenant_action = ResourceInfo.get_action(Post, :destroy, false)

      assert master_action == :destroy
      assert tenant_action == :destroy
    end

    test "User read action uses domain defaults (no source section)" do
      master_action = ResourceInfo.get_action(User, :read, true)
      tenant_action = ResourceInfo.get_action(User, :read, false)

      assert master_action == :master_read
      assert tenant_action == :read
    end

    test "Comment read action uses domain defaults (no source section)" do
      master_action = ResourceInfo.get_action(Comment, :read, true)
      tenant_action = ResourceInfo.get_action(Comment, :read, false)

      assert master_action == :master_read
      assert tenant_action == :read
    end
  end

  describe "get_action/3 edge cases" do
    test "MinimalResource inherits the domain tuple action" do
      master = ResourceInfo.get_action(MinimalResource, :read, true)
      tenant = ResourceInfo.get_action(MinimalResource, :read, false)

      assert master == :master_read
      assert tenant == :read
    end

    test "handles tuple action (Post)" do
      master = ResourceInfo.get_action(Post, :read, true)
      tenant = ResourceInfo.get_action(Post, :read, false)

      assert master == :master_read
      assert tenant == :tenant_read
    end

    test "handles all action types for MinimalResource" do
      for action_type <- [:read, :get, :destroy] do
        master = ResourceInfo.get_action(MinimalResource, action_type, true)
        tenant = ResourceInfo.get_action(MinimalResource, action_type, false)

        assert is_atom(master)
        assert is_atom(tenant)
      end
    end

    test "handles all action types for Post" do
      for action_type <- [:read, :destroy] do
        master = ResourceInfo.get_action(Post, action_type, true)
        tenant = ResourceInfo.get_action(Post, action_type, false)

        assert is_atom(master)
        assert is_atom(tenant)
      end
    end

    test "DslOverrideResource get_action resolves tuples correctly" do
      master_get = ResourceInfo.get_action(DslOverrideResource, :get, true)
      tenant_get = ResourceInfo.get_action(DslOverrideResource, :get, false)

      assert master_get == :custom_master_get
      assert tenant_get == :custom_get
    end
  end

  # Preloads

  describe "detected_preloads/1" do
    test "Post detected_preloads is empty (list source doesn't extract)" do
      preloads = ResourceInfo.detected_preloads(Post)

      # Post uses [:user, :name] list format which doesn't extract preloads
      assert preloads == []
    end

    test "Comment detected_preloads is empty (list source doesn't extract)" do
      preloads = ResourceInfo.detected_preloads(Comment)

      # Comment uses [:user, :name] and [:post, :title] list formats
      assert preloads == []
    end
  end

  describe "all_preloads/2" do
    test "Post all_preloads for tenant includes :user from always preload" do
      preloads = ResourceInfo.all_preloads(Post, false)

      assert :user in preloads
    end

    test "Post all_preloads for master includes :user from always preload" do
      preloads = ResourceInfo.all_preloads(Post, true)

      assert :user in preloads
    end

    test "Comment all_preloads includes :user and :post from always preload" do
      preloads = ResourceInfo.all_preloads(Comment, false)

      assert :user in preloads
      assert :post in preloads
    end
  end

  # stream_name/1

  describe "stream_name/1" do
    test "Post stream_name is :posts_stream" do
      name = ResourceInfo.stream_name(Post)

      assert name == :posts_stream
    end

    test "User stream_name is auto-generated :users_stream" do
      name = ResourceInfo.stream_name(User)

      assert name == :users_stream
    end

    test "Comment stream_name is auto-generated :comments_stream" do
      name = ResourceInfo.stream_name(Comment)

      assert name == :comments_stream
    end
  end

  # hooks/1

  describe "hooks/1" do
    test "Post hooks has all expected keys" do
      hooks = ResourceInfo.hooks(Post)

      assert Map.has_key?(hooks, :on_load)
      assert Map.has_key?(hooks, :before_delete)
      assert Map.has_key?(hooks, :after_delete)
      assert Map.has_key?(hooks, :on_filter)
      assert Map.has_key?(hooks, :on_select)
      assert Map.has_key?(hooks, :on_sort)
    end

    test "Post on_load hook is a function with arity 2" do
      hooks = ResourceInfo.hooks(Post)

      assert is_function(hooks.on_load, 2)
    end

    test "Post before_delete hook is a function with arity 2" do
      hooks = ResourceInfo.hooks(Post)

      assert is_function(hooks.before_delete, 2)
    end

    test "Post after_delete hook is a function with arity 2" do
      hooks = ResourceInfo.hooks(Post)

      assert is_function(hooks.after_delete, 2)
    end

    test "Post on_filter hook is a function with arity 2" do
      hooks = ResourceInfo.hooks(Post)

      assert is_function(hooks.on_filter, 2)
    end

    test "Post on_select hook is a function with arity 2" do
      hooks = ResourceInfo.hooks(Post)

      assert is_function(hooks.on_select, 2)
    end

    test "Post on_sort hook is a function with arity 2" do
      hooks = ResourceInfo.hooks(Post)

      assert is_function(hooks.on_sort, 2)
    end

    test "User hooks returns empty map when no hooks configured" do
      hooks = ResourceInfo.hooks(User)

      # User doesn't define any hooks
      assert hooks == %{}
    end
  end

  # refresh_config/1

  describe "refresh_config/1" do
    test "Post refresh_config has enabled false" do
      config = ResourceInfo.refresh_config(Post)

      assert config.enabled == false
    end
  end

  # url_sync_config/1

  describe "url_sync_config/1" do
    test "Post url_sync_config has enabled true" do
      config = ResourceInfo.url_sync_config(Post)

      assert config.enabled == true
    end

    test "Post url_sync_config has correct params" do
      config = ResourceInfo.url_sync_config(Post)

      assert config.params == [:page, :sort, :search, :filters]
    end

    test "Post url_sync_config has max_filter_length with default value 500" do
      config = ResourceInfo.url_sync_config(Post)

      assert config.max_filter_length == 500
    end

    test "Post url_sync_config has mode :bidirectional" do
      config = ResourceInfo.url_sync_config(Post)

      assert config.mode == :bidirectional
    end
  end

  # Pagination

  describe "pagination config" do
    test "Post pagination has correct values" do
      config = ResourceInfo.table_config(Post)

      assert config.pagination.page_size == 25
      assert config.pagination.type == :infinite
    end

    test "User pagination has correct values" do
      config = ResourceInfo.table_config(User)

      assert config.pagination.page_size == 20
      assert config.pagination.type == :numbered
    end

    test "Comment pagination has correct values" do
      config = ResourceInfo.table_config(Comment)

      assert config.pagination.page_size == 50
      assert config.pagination.type == :numbered
    end
  end

  # Pagination info functions

  describe "pagination/1" do
    test "Post pagination returns full config" do
      pagination = ResourceInfo.pagination(Post)

      assert is_map(pagination)
      assert pagination.page_size == 25
      assert pagination.type == :infinite
    end

    test "User pagination returns full config" do
      pagination = ResourceInfo.pagination(User)

      assert pagination.page_size == 20
      assert pagination.type == :numbered
    end
  end

  describe "pagination_enabled?/1" do
    test "returns true for resources with pagination" do
      assert ResourceInfo.pagination_enabled?(Post)
      assert ResourceInfo.pagination_enabled?(User)
    end
  end

  describe "pagination_type/1" do
    test "Post pagination type is infinite" do
      assert ResourceInfo.pagination_type(Post) == :infinite
    end

    test "User pagination type is numbered" do
      assert ResourceInfo.pagination_type(User) == :numbered
    end
  end

  describe "page_size/1" do
    test "Post page_size is 25" do
      assert ResourceInfo.page_size(Post) == 25
    end

    test "User page_size is 20" do
      assert ResourceInfo.page_size(User) == 20
    end
  end

  describe "page_size_options/1" do
    test "returns nil when not configured" do
      assert ResourceInfo.page_size_options(Post) == nil
      assert ResourceInfo.page_size_options(User) == nil
    end
  end

  describe "max_page_size/1" do
    test "returns default 150 when not explicitly set" do
      assert ResourceInfo.max_page_size(Post) == 150
      assert ResourceInfo.max_page_size(User) == 150
    end
  end

  # Empty and Error States

  describe "empty_state config" do
    test "Post empty_state has correct message" do
      config = ResourceInfo.table_config(Post)

      assert config.empty_state.message == "No posts found"
      assert config.empty_state.icon == "hero-document-text"
    end
  end

  describe "error_state config" do
    test "Post error_state has correct message" do
      config = ResourceInfo.table_config(Post)

      assert config.error_state.message == "Failed to load posts"
    end
  end

  # Realtime

  describe "realtime config" do
    test "Post realtime has expected structure" do
      config = ResourceInfo.table_config(Post)

      assert Map.has_key?(config.realtime, :enabled)
      assert Map.has_key?(config.realtime, :prefix)
    end
  end

  # Presentation

  describe "presentation config" do
    test "Post ui_adapter is Tailwind" do
      config = ResourceInfo.table_config(Post)

      assert config.presentation.ui_adapter == MishkaGervaz.UIAdapters.Tailwind
    end
  end

  # Source config

  describe "source config" do
    test "Post source has correct actor_key" do
      config = ResourceInfo.table_config(Post)

      assert config.source.actor_key == :current_user
    end

    test "Post source has correct actions (developer-configured tuples)" do
      config = ResourceInfo.table_config(Post)

      assert config.source.actions.read == {:master_read, :tenant_read}
      assert config.source.actions.destroy == {:destroy, :destroy}
    end

    test "Post source has correct always preloads" do
      config = ResourceInfo.table_config(Post)

      assert config.source.preload.always == [:user]
    end

    test "Post source master_check is a function" do
      config = ResourceInfo.table_config(Post)

      assert is_function(config.source.master_check, 1)
    end

    test "Comment source has correct always preloads" do
      config = ResourceInfo.table_config(Comment)

      assert config.source.preload.always == [:user, :post]
    end
  end

  # Row config

  describe "row config" do
    test "Post row is selectable" do
      config = ResourceInfo.table_config(Post)

      assert config.row.selectable == true
    end
  end

  # Features

  describe "features/1" do
    alias MishkaGervaz.Resource.Info.Table, as: TableInfo
    alias MishkaGervaz.Test.Resources.ComplexTestResource

    test "returns template default features when DSL features is nil" do
      # Post doesn't have features set in DSL
      features = TableInfo.features(Post)

      # Should return all features from template.features()
      assert is_list(features)
      assert :sort in features
      assert :filter in features
      assert :paginate in features
    end

    test "returns specific features when DSL has a list" do
      # ComplexTestResource has features: [:sort, :filter, :select, :paginate]
      features = TableInfo.features(ComplexTestResource)

      assert features == [:sort, :filter, :select, :paginate]
      refute :bulk_actions in features
      refute :expand in features
    end

    test "always returns a list, never :all" do
      features = TableInfo.features(Post)

      assert is_list(features)
      refute features == :all
    end
  end

  describe "feature_enabled?/2" do
    alias MishkaGervaz.Resource.Info.Table, as: TableInfo
    alias MishkaGervaz.Test.Resources.ComplexTestResource

    test "returns true for enabled features" do
      assert TableInfo.feature_enabled?(ComplexTestResource, :sort)
      assert TableInfo.feature_enabled?(ComplexTestResource, :filter)
      assert TableInfo.feature_enabled?(ComplexTestResource, :select)
      assert TableInfo.feature_enabled?(ComplexTestResource, :paginate)
    end

    test "returns false for disabled features" do
      refute TableInfo.feature_enabled?(ComplexTestResource, :bulk_actions)
      refute TableInfo.feature_enabled?(ComplexTestResource, :expand)
      refute TableInfo.feature_enabled?(ComplexTestResource, :inline_edit)
    end

    test "returns true for all template features when DSL is nil" do
      assert TableInfo.feature_enabled?(Post, :sort)
      assert TableInfo.feature_enabled?(Post, :filter)
      assert TableInfo.feature_enabled?(Post, :paginate)
    end
  end
end
