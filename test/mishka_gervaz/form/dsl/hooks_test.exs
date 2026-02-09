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

  describe "MinimalForm hooks" do
    test "hooks returns empty map when not configured" do
      hooks = FormInfo.hooks(MinimalForm)
      assert hooks == %{}
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
end
