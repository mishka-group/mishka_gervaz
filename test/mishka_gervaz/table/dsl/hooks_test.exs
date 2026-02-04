defmodule MishkaGervaz.DSL.HooksTest do
  @moduledoc """
  Tests for the hooks DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.{Post, ComplexTestResource}

  describe "hooks configuration" do
    test "hooks config is present" do
      config = ResourceInfo.table_config(Post)
      assert config.hooks != nil
    end

    test "on_load hook is configured as function" do
      config = ResourceInfo.table_config(Post)
      assert is_function(config.hooks.on_load, 2)
    end

    test "on_load hook returns socket" do
      config = ResourceInfo.table_config(Post)
      socket = %{test: true}
      result = config.hooks.on_load.(socket, [])
      assert result == socket
    end
  end

  describe "all hooks keys (ComplexTestResource)" do
    test "on_load hook is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.hooks.on_load, 2)
    end

    test "before_delete hook is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.hooks.before_delete, 2)
    end

    test "after_delete hook is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.hooks.after_delete, 2)
    end

    test "on_filter hook is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.hooks.on_filter, 2)
    end

    test "on_select hook is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.hooks.on_select, 2)
    end

    test "on_sort hook is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_function(config.hooks.on_sort, 2)
    end
  end

  describe "optional hooks not configured in ComplexTestResource" do
    test "on_realtime hook is nil when not configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.hooks[:on_realtime] == nil
    end

    test "on_expand hook is nil when not configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.hooks[:on_expand] == nil
    end

    test "on_event hook is nil when not configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.hooks[:on_event] == nil
    end
  end

  describe "hooks via TableInfo" do
    test "TableInfo.hooks/1 returns all hooks as a map" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_map(hooks)
      assert Map.has_key?(hooks, :on_load)
      assert Map.has_key?(hooks, :before_delete)
      assert Map.has_key?(hooks, :after_delete)
    end

    test "TableInfo.hooks/1 contains functions" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks.on_load, 2)
    end
  end

  describe "hooks DSL schema" do
    test "all hooks are optional (no defaults)" do
      schema = MishkaGervaz.Table.Dsl.Hooks.schema()

      # Verify all hooks have no default (they're optional)
      for {key, config} <- schema do
        assert Keyword.get(config, :default) == nil,
               "Hook #{key} should have no default"
      end
    end

    test "hooks have correct arity" do
      schema = MishkaGervaz.Table.Dsl.Hooks.schema()

      # Most hooks are fun/2
      for key <- [
            :on_load,
            :before_delete,
            :after_delete,
            :on_realtime,
            :on_expand,
            :on_filter,
            :on_select,
            :on_sort
          ] do
        config = Keyword.get(schema, key)
        assert Keyword.get(config, :type) == {:fun, 2}
      end

      # on_event is fun/3
      on_event_config = Keyword.get(schema, :on_event)
      assert Keyword.get(on_event_config, :type) == {:fun, 3}
    end
  end
end
