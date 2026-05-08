defmodule MishkaGervaz.Form.Web.Events.HookRunnerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.HookRunner.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.HookRunner.Default, as: HookRunner

  describe "run_hook/3" do
    test "invokes the function under hook_name with given args" do
      hooks = %{on_validate: fn params, _state -> {:cont, Map.put(params, "added", true)} end}

      assert HookRunner.run_hook(hooks, :on_validate, [%{}, %{}]) ==
               {:cont, %{"added" => true}}
    end

    test "returns nil when hook is missing" do
      assert HookRunner.run_hook(%{}, :ghost, []) == nil
    end

    test "returns nil when hook value is not a function" do
      assert HookRunner.run_hook(%{on_init: :not_a_fn}, :on_init, []) == nil
    end

    test "returns nil for non-map hooks" do
      assert HookRunner.run_hook(nil, :on_init, []) == nil
      assert HookRunner.run_hook(:gibberish, :on_init, []) == nil
    end
  end

  describe "apply_hook_result/2" do
    test "{:cont, modified} → modified" do
      assert HookRunner.apply_hook_result({:cont, %{a: 2}}, %{a: 1}) == %{a: 2}
    end

    test "{:halt, _} → original" do
      assert HookRunner.apply_hook_result({:halt, :ignored}, %{a: 1}) == %{a: 1}
    end

    test "anything else → original" do
      assert HookRunner.apply_hook_result(nil, %{a: 1}) == %{a: 1}
      assert HookRunner.apply_hook_result(:gibberish, %{a: 1}) == %{a: 1}
    end
  end

  describe "override pattern" do
    test "user can override run_hook via use" do
      defmodule TestEventsHookRunnerOverride do
        use MishkaGervaz.Form.Web.Events.HookRunner

        def run_hook(_hooks, :always_cont, _args), do: {:cont, :overridden}
        def run_hook(hooks, name, args), do: super(hooks, name, args)
      end

      assert TestEventsHookRunnerOverride.run_hook(%{}, :always_cont, []) ==
               {:cont, :overridden}

      assert TestEventsHookRunnerOverride.run_hook(%{}, :anything_else, []) == nil
    end
  end
end
