defmodule MishkaGervaz.DSL.StatesTest do
  @moduledoc """
  Tests for the empty_state and error_state DSL sections.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, ComplexTestResource}

  describe "empty_state configuration" do
    test "empty_state config is present" do
      config = ResourceInfo.table_config(Post)
      assert config.empty_state != nil
    end

    test "empty_state message is configured" do
      config = ResourceInfo.table_config(Post)
      assert config.empty_state.message == "No posts found"
    end

    test "empty_state icon is configured" do
      config = ResourceInfo.table_config(Post)
      assert config.empty_state.icon == "hero-document-text"
    end
  end

  describe "error_state configuration" do
    test "error_state config is present" do
      config = ResourceInfo.table_config(Post)
      assert config.error_state != nil
    end

    test "error_state message is configured" do
      config = ResourceInfo.table_config(Post)
      assert config.error_state.message == "Failed to load posts"
    end
  end

  describe "all EmptyState entity keys (ComplexTestResource)" do
    test "message key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.message == "No posts found"
    end

    test "icon key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.icon == "hero-document-text"
    end

    test "action label key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      # action keys are nested under :action
      assert config.empty_state.action.label == "Create Post"
    end

    test "action path key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.action.path == "/admin/complex-posts/new"
    end

    test "action icon key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.empty_state.action.icon == "hero-plus"
    end
  end

  describe "all ErrorState entity keys (ComplexTestResource)" do
    test "message key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.error_state.message == "Failed to load posts"
    end

    test "icon key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.error_state.icon == "hero-exclamation-circle"
    end

    test "retry_label key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.error_state.retry_label == "Try Again"
    end
  end

  describe "empty_state and error_state have expected structure" do
    test "empty_state is a map with all expected keys" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.empty_state)
      assert Map.has_key?(config.empty_state, :message)
      assert Map.has_key?(config.empty_state, :icon)
      # action keys are nested under :action
      assert Map.has_key?(config.empty_state, :action)
      assert Map.has_key?(config.empty_state.action, :label)
      assert Map.has_key?(config.empty_state.action, :path)
      assert Map.has_key?(config.empty_state.action, :icon)
    end

    test "error_state is a map with all expected keys" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.error_state)
      assert Map.has_key?(config.error_state, :message)
      assert Map.has_key?(config.error_state, :icon)
      assert Map.has_key?(config.error_state, :retry_label)
    end
  end
end
