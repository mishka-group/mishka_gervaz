defmodule MishkaGervaz.Resource.Info.TableInfoTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Resource.Info.Table` accessors, focused on
  edge cases not covered by feature-area tests:

  - chrome (header/footer/notices) negative cases
  - archive enabled/action negative cases
  - state/events/data_loader empty defaults
  - pagination accessors fall through to nil when disabled

  Resource-level happy paths and ResourceInfo delegate coverage live in:
  `test/mishka_gervaz/table/dsl/chrome_test.exs`,
  `test/mishka_gervaz/info/resource_info_test.exs`, etc.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Table, as: TableInfo

  alias MishkaGervaz.Test.Resources.{
    ArchivableResource,
    ChromeTable,
    MinimalResource,
    Post
  }

  describe "layout/1 — negative cases" do
    test "returns nil for resource without layout block" do
      assert TableInfo.layout(MinimalResource) == nil
    end

    test "returns nil for Post (no chrome configured)" do
      assert TableInfo.layout(Post) == nil
    end
  end

  describe "header/1 — negative cases" do
    test "returns nil for resource without layout" do
      assert TableInfo.header(MinimalResource) == nil
    end

    test "returns nil for Post" do
      assert TableInfo.header(Post) == nil
    end
  end

  describe "footer/1 — negative cases" do
    test "returns nil for resource without layout" do
      assert TableInfo.footer(MinimalResource) == nil
    end

    test "returns nil for Post" do
      assert TableInfo.footer(Post) == nil
    end
  end

  describe "notices/1 — negative cases" do
    test "returns empty list for resource without layout" do
      assert TableInfo.notices(MinimalResource) == []
    end

    test "returns empty list for Post" do
      assert TableInfo.notices(Post) == []
    end
  end

  describe "notice/2 — negative cases" do
    test "returns nil for non-existent notice on chrome resource" do
      assert TableInfo.notice(ChromeTable, :nonexistent) == nil
    end

    test "returns nil for resource without layout" do
      assert TableInfo.notice(MinimalResource, :anything) == nil
    end
  end

  describe "archive_enabled?/1" do
    test "true for resource using AshArchival" do
      assert TableInfo.archive_enabled?(ArchivableResource) == true
    end

    test "false for non-archivable Post" do
      assert TableInfo.archive_enabled?(Post) == false
    end

    test "false for MinimalResource" do
      assert TableInfo.archive_enabled?(MinimalResource) == false
    end
  end

  describe "archive_action_for/3 — negative cases" do
    test "returns nil for non-archivable resource" do
      assert TableInfo.archive_action_for(Post, :read, true) == nil
      assert TableInfo.archive_action_for(Post, :read, false) == nil
      assert TableInfo.archive_action_for(Post, :destroy, true) == nil
    end

    test "returns nil for MinimalResource" do
      assert TableInfo.archive_action_for(MinimalResource, :restore, true) == nil
    end
  end

  describe "archive_action_for/3 on archivable resource" do
    test "returns master action for master user when configured as tuple" do
      result = TableInfo.archive_action_for(ArchivableResource, :read, true)
      assert is_atom(result)
      refute is_nil(result)
    end

    test "returns tenant action for tenant user when configured as tuple" do
      result = TableInfo.archive_action_for(ArchivableResource, :read, false)
      assert is_atom(result)
      refute is_nil(result)
    end
  end

  describe "state/1, events/1, data_loader/1 — empty defaults" do
    test "state returns empty map for resource without overrides" do
      assert TableInfo.state(Post) == %{}
    end

    test "events returns empty map for resource without overrides" do
      assert TableInfo.events(Post) == %{}
    end

    test "data_loader returns empty map for resource without overrides" do
      assert TableInfo.data_loader(Post) == %{}
    end

    test "all three return empty map for MinimalResource" do
      assert TableInfo.state(MinimalResource) == %{}
      assert TableInfo.events(MinimalResource) == %{}
      assert TableInfo.data_loader(MinimalResource) == %{}
    end
  end

  describe "filter_groups/1 — negative cases" do
    test "returns empty list when not configured" do
      assert TableInfo.filter_groups(MinimalResource) == []
    end
  end

  describe "filter_mode/1" do
    test "defaults to :inline when not configured" do
      assert TableInfo.filter_mode(MinimalResource) == :inline
    end
  end

  describe "pagination accessor chain on Post (paginated resource)" do
    test "pagination/1 returns a map" do
      assert is_map(TableInfo.pagination(Post))
    end

    test "pagination_enabled?/1 is true" do
      assert TableInfo.pagination_enabled?(Post) == true
    end

    test "pagination_type/1 returns the configured type" do
      assert is_atom(TableInfo.pagination_type(Post))
    end

    test "page_size/1 returns a positive integer" do
      assert is_integer(TableInfo.page_size(Post))
      assert TableInfo.page_size(Post) > 0
    end

    test "max_page_size/1 returns an integer" do
      assert is_integer(TableInfo.max_page_size(Post))
    end
  end

  describe "preload_aliases/2 — empty cases" do
    test "returns empty map when no aliases on Post" do
      assert TableInfo.preload_aliases(Post, true) == %{}
      assert TableInfo.preload_aliases(Post, false) == %{}
    end

    test "returns empty map for MinimalResource" do
      assert TableInfo.preload_aliases(MinimalResource, true) == %{}
    end
  end
end
