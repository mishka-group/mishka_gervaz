defmodule MishkaGervaz.Form.DSL.HooksTest do
  @moduledoc """
  Tests for the form hooks DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    MinimalForm
  }

  describe "FormPost hooks" do
    test "hooks config is present" do
      hooks = FormInfo.hooks(FormPost)
      assert is_map(hooks)
      assert hooks != %{}
    end

    test "on_init is function/2" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.on_init, 2)
    end

    test "before_save is function/2" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.before_save, 2)
    end

    test "after_save is function/2" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.after_save, 2)
    end

    test "on_error is function/2" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.on_error, 2)
    end

    test "on_cancel is function/1" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.on_cancel, 1)
    end

    test "on_validate is function/2" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.on_validate, 2)
    end

    test "on_change is function/3" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.on_change, 3)
    end

    test "transform_params is function/1" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.transform_params, 1)
    end

    test "transform_errors is function/2" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.transform_errors, 2)
    end
  end

  describe "FormPost JS hooks" do
    test "js sub-map is present in hooks" do
      hooks = FormInfo.hooks(FormPost)
      assert is_map(hooks.js)
    end

    test "js on_init is function/0" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.js.on_init, 0)
    end

    test "js after_save is function/1" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.js.after_save, 1)
    end

    test "js on_cancel is function/1" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.js.on_cancel, 1)
    end

    test "js on_error is function/1" do
      hooks = FormInfo.hooks(FormPost)
      assert is_function(hooks.js.on_error, 1)
    end

    test "js on_init returns JS struct" do
      hooks = FormInfo.hooks(FormPost)
      result = hooks.js.on_init.()
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "js after_save returns JS struct" do
      hooks = FormInfo.hooks(FormPost)
      result = hooks.js.after_save.(nil)
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "js on_cancel returns JS struct" do
      hooks = FormInfo.hooks(FormPost)
      result = hooks.js.on_cancel.(nil)
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "js on_error returns JS struct" do
      hooks = FormInfo.hooks(FormPost)
      result = hooks.js.on_error.(nil)
      assert is_struct(result, Phoenix.LiveView.JS)
    end
  end

  describe "MinimalForm hooks" do
    test "hooks returns empty map when not configured" do
      hooks = FormInfo.hooks(MinimalForm)
      assert hooks == %{}
    end

    test "js hooks are not present when not configured" do
      hooks = FormInfo.hooks(MinimalForm)
      assert hooks == %{}
      refute Map.has_key?(hooks, :js)
    end
  end

  describe "hooks DSL schema" do
    test "all hooks are optional (no defaults)" do
      schema = MishkaGervaz.Form.Dsl.Hooks.schema()

      for {key, config} <- schema do
        assert Keyword.get(config, :default) == nil,
               "Hook #{key} should have no default"
      end
    end

    test "hooks have correct arity types" do
      schema = MishkaGervaz.Form.Dsl.Hooks.schema()

      # function/2 hooks
      for key <- [:on_init, :before_save, :after_save, :on_error, :on_validate, :transform_errors] do
        config = Keyword.get(schema, key)
        assert Keyword.get(config, :type) == {:fun, 2}, "#{key} should be fun/2"
      end

      # function/1 hooks
      for key <- [:on_cancel, :transform_params] do
        config = Keyword.get(schema, key)
        assert Keyword.get(config, :type) == {:fun, 1}, "#{key} should be fun/1"
      end

      # function/3 hooks
      config = Keyword.get(schema, :on_change)
      assert Keyword.get(config, :type) == {:fun, 3}
    end
  end

  describe "JS hooks DSL schema" do
    test "js_schema returns keyword list" do
      schema = MishkaGervaz.Form.Dsl.Hooks.js_schema()
      assert is_list(schema)
    end

    test "js on_init is fun/0" do
      schema = MishkaGervaz.Form.Dsl.Hooks.js_schema()
      config = Keyword.get(schema, :on_init)
      assert Keyword.get(config, :type) == {:fun, 0}
    end

    test "js after_save is fun/1" do
      schema = MishkaGervaz.Form.Dsl.Hooks.js_schema()
      config = Keyword.get(schema, :after_save)
      assert Keyword.get(config, :type) == {:fun, 1}
    end

    test "js on_cancel is fun/1" do
      schema = MishkaGervaz.Form.Dsl.Hooks.js_schema()
      config = Keyword.get(schema, :on_cancel)
      assert Keyword.get(config, :type) == {:fun, 1}
    end

    test "js on_error is fun/1" do
      schema = MishkaGervaz.Form.Dsl.Hooks.js_schema()
      config = Keyword.get(schema, :on_error)
      assert Keyword.get(config, :type) == {:fun, 1}
    end

    test "all JS hooks are optional (no defaults)" do
      schema = MishkaGervaz.Form.Dsl.Hooks.js_schema()

      for {key, config} <- schema do
        assert Keyword.get(config, :default) == nil,
               "JS hook #{key} should have no default"
      end
    end
  end
end
