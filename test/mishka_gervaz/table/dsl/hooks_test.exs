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

  describe "per-action hooks" do
    test "before_row_action stored under {phase, name} key" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:before_row_action, :delete}], 2)
    end

    test "before_row_action expands list of names into separate keys" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:before_row_action, :unarchive}], 2)
      assert is_function(hooks[{:before_row_action, :permanent_destroy}], 2)
    end

    test "after_row_action keyed by action name" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:after_row_action, :delete}], 2)
    end

    test "on_row_action_success / on_row_action_error keyed correctly" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:on_row_action_success, :unarchive}], 2)
      assert is_function(hooks[{:on_row_action_error, :delete}], 2)
    end

    test "before_bulk_action / after_bulk_action / success / error keyed correctly" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:before_bulk_action, :destroy}], 2)
      assert is_function(hooks[{:after_bulk_action, :destroy}], 2)
      assert is_function(hooks[{:on_bulk_action_success, :destroy}], 2)
      assert is_function(hooks[{:on_bulk_action_error, :destroy}], 2)
    end

    test "override_row_action aliases to legacy {:on_event, name} runtime key" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:on_event, "custom_event"}], 2)
    end

    test "override_bulk_action aliases to legacy {:on_bulk_action, name} runtime key" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_function(hooks[{:on_bulk_action, "custom_bulk"}], 2)
    end
  end

  describe "builtins" do
    test "TableInfo.builtins/1 returns the configured map" do
      builtins = TableInfo.builtins(ComplexTestResource)
      assert is_map(builtins)
      assert builtins.switch_to_active_on_empty_archive == true
      assert builtins.clear_selection_after_bulk == true
      assert builtins.reset_page_on_empty_current_page == true
    end

    test "non-configured builtins fall back to schema defaults" do
      builtins = TableInfo.builtins(ComplexTestResource)
      assert builtins.switch_to_archive_on_empty_active == false
      assert builtins.redirect_on_empty == nil
    end

    test "hooks map exposes builtins under :__builtins__" do
      hooks = TableInfo.hooks(ComplexTestResource)
      assert is_map(hooks[:__builtins__])
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
