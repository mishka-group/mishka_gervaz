defmodule MishkaGervaz.Form.Web.DataLoader.HookRunnerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.DataLoader.HookRunner.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.DataLoader.HookRunner.Default, as: HookRunner

  describe "run_hook/3" do
    test "invokes the function under hook_name with given args" do
      hooks = %{on_init: fn form, _state -> {:cont, "modified-#{form}"} end}
      assert HookRunner.run_hook(hooks, :on_init, ["F", %{}]) == {:cont, "modified-F"}
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
      assert HookRunner.apply_hook_result({:cont, "new"}, "old") == "new"
    end

    test "{:halt, _} → original" do
      assert HookRunner.apply_hook_result({:halt, :ignored}, "old") == "old"
    end

    test "anything else → original" do
      assert HookRunner.apply_hook_result(nil, "old") == "old"
      assert HookRunner.apply_hook_result(:gibberish, "old") == "old"
    end
  end

  describe "override pattern" do
    test "user can override run_hook via use" do
      defmodule TestHookRunnerOverride do
        use MishkaGervaz.Form.Web.DataLoader.HookRunner

        def run_hook(_hooks, :always_cont, _args), do: {:cont, :overridden}
        def run_hook(hooks, name, args), do: super(hooks, name, args)
      end

      assert TestHookRunnerOverride.run_hook(%{}, :always_cont, []) == {:cont, :overridden}
      assert TestHookRunnerOverride.run_hook(%{}, :anything_else, []) == nil
    end
  end
end
