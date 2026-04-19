defmodule MishkaGervaz.DSL.PaginationTest do
  @moduledoc """
  Tests for the pagination section of the MishkaGervaz DSL.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, User, Comment, MinimalResource}

  describe "pagination configuration" do
    test "Post has pagination configured" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination != nil
    end

    test "Post page_size is set correctly" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination.page_size == 25
    end

    test "Post pagination type is infinite" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination.type == :infinite
    end
  end

  describe "numbered pagination" do
    test "User has numbered pagination" do
      config = ResourceInfo.table_config(User)
      assert config.pagination.type == :numbered
    end

    test "User page_size is 20" do
      config = ResourceInfo.table_config(User)
      assert config.pagination.page_size == 20
    end

    test "Comment has numbered pagination" do
      config = ResourceInfo.table_config(Comment)
      assert config.pagination.type == :numbered
    end

    test "Comment page_size is 50" do
      config = ResourceInfo.table_config(Comment)
      assert config.pagination.page_size == 50
    end
  end

  describe "pagination types" do
    test "infinite pagination type" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination.type == :infinite
    end

    test "numbered pagination type" do
      config = ResourceInfo.table_config(User)
      assert config.pagination.type == :numbered
    end
  end

  describe "max_page_size" do
    test "max_page_size defaults to 150 when not set" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination.max_page_size == 150
    end

    test "max_page_size is present in User pagination" do
      config = ResourceInfo.table_config(User)
      assert config.pagination.max_page_size == 150
    end
  end

  describe "page_size_options" do
    test "page_size_options defaults to nil when not set" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination.page_size_options == nil
    end

    test "page_size_options defaults to nil for User" do
      config = ResourceInfo.table_config(User)
      assert config.pagination.page_size_options == nil
    end
  end

  describe "pagination enabled flag" do
    test "pagination is present when not explicitly disabled" do
      config = ResourceInfo.table_config(Post)
      assert config.pagination != nil
    end

    test "User pagination is present" do
      config = ResourceInfo.table_config(User)
      assert config.pagination != nil
    end
  end

  describe "pagination priority: resource > domain > DSL default" do
    test "resource with explicit pagination type keeps its value over domain defaults" do
      # Post explicitly sets type: :infinite, domain has type: :numbered
      config = ResourceInfo.table_config(Post)
      assert config.pagination.type == :infinite
    end

    test "resource with explicit page_size keeps its value over domain defaults" do
      # Post explicitly sets page_size: 25, domain has page_size: 20
      config = ResourceInfo.table_config(Post)
      assert config.pagination.page_size == 25
    end

    test "resource without pagination inherits domain defaults for type" do
      # MinimalResource has no pagination section, domain has type: :numbered
      config = ResourceInfo.table_config(MinimalResource)
      assert config.pagination.type == :numbered
    end

    test "resource without pagination inherits domain defaults for page_size" do
      # MinimalResource has no pagination section, domain has page_size: 20
      config = ResourceInfo.table_config(MinimalResource)
      assert config.pagination.page_size == 20
    end

    test "resource with DSL default type uses domain default when available" do
      # MinimalResource uses DSL default (:load_more), but domain has :numbered
      # Domain default should override DSL default
      config = ResourceInfo.table_config(MinimalResource)
      assert config.pagination.type == :numbered
      refute config.pagination.type == :load_more
    end

    test "resource with DSL default page_size uses domain default when available" do
      # MinimalResource uses DSL default (20), domain also has 20
      # This should still work even when values match
      config = ResourceInfo.table_config(MinimalResource)
      assert config.pagination.page_size == 20
    end
  end
end
