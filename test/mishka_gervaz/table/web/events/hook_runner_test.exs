defmodule MishkaGervaz.Table.Web.Events.HookRunnerTest do
  @moduledoc """
  Tests for the default HookRunner — verifies dispatch by global atom keys
  and by per-action `{phase, name}` tuple keys.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Events.HookRunner.Default, as: HookRunner

  defp socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{assigns: Map.merge(%{__changed__: %{}}, assigns)}
  end

  describe "run_hook/3 — global atom keys" do
    test "invokes function under atom key" do
      hooks = %{on_load: fn query, _state -> {:cont, query} end}
      assert HookRunner.run_hook(hooks, :on_load, [:query, %{}]) == {:cont, :query}
    end

    test "returns nil when key is missing" do
      assert HookRunner.run_hook(%{}, :on_load, []) == nil
    end

    test "returns nil when hooks is nil" do
      assert HookRunner.run_hook(nil, :on_load, []) == nil
    end
  end

  describe "run_hook/3 — per-action tuple keys" do
    test "invokes function under {:before_row_action, :name}" do
      ref = make_ref()

      hooks = %{
        {:before_row_action, :delete} => fn _record, _state -> {:halt, {:error, ref}} end
      }

      assert HookRunner.run_hook(hooks, {:before_row_action, :delete}, [%{}, %{}]) ==
               {:halt, {:error, ref}}
    end

    test "invokes function under {:after_row_action, :name}" do
      hooks = %{{:after_row_action, :delete} => fn result, _state -> {:got, result} end}
      assert HookRunner.run_hook(hooks, {:after_row_action, :delete}, [{:ok, :rec}, %{}]) ==
               {:got, {:ok, :rec}}
    end

    test "different action names are dispatched independently" do
      hooks = %{
        {:before_row_action, :delete} => fn _, _ -> :delete_hit end,
        {:before_row_action, :unarchive} => fn _, _ -> :unarchive_hit end
      }

      assert HookRunner.run_hook(hooks, {:before_row_action, :delete}, [nil, nil]) == :delete_hit

      assert HookRunner.run_hook(hooks, {:before_row_action, :unarchive}, [nil, nil]) ==
               :unarchive_hit
    end

    test "missing per-action key returns nil" do
      hooks = %{{:before_row_action, :delete} => fn _, _ -> :hit end}
      assert HookRunner.run_hook(hooks, {:before_row_action, :other}, [nil, nil]) == nil
      assert HookRunner.run_hook(hooks, {:after_row_action, :delete}, [nil, nil]) == nil
    end
  end

  describe "apply_hook_result/4" do
    test "returns default socket when hook missing" do
      default = socket()
      assert HookRunner.apply_hook_result(%{}, :on_filter, [%{}, default], default) == default
    end

    test "returns {:halt, socket} when hook returns {:halt, socket}" do
      halted = socket(%{halted: true})
      hooks = %{on_filter: fn _, _ -> {:halt, halted} end}

      assert HookRunner.apply_hook_result(hooks, :on_filter, [%{}, socket()], socket()) ==
               {:halt, halted}
    end

    test "unwraps {:cont, socket} → socket" do
      cont_socket = socket(%{cont: true})
      hooks = %{on_filter: fn _, _ -> {:cont, cont_socket} end}

      assert HookRunner.apply_hook_result(hooks, :on_filter, [%{}, socket()], socket()) ==
               cont_socket
    end

    test "returns socket directly when hook returns a socket" do
      direct = socket(%{direct: true})
      hooks = %{on_filter: fn _, _ -> direct end}

      assert HookRunner.apply_hook_result(hooks, :on_filter, [%{}, socket()], socket()) == direct
    end

    test "falls back to default when hook returns garbage" do
      default = socket(%{default: true})
      hooks = %{on_filter: fn _, _ -> :nope end}

      assert HookRunner.apply_hook_result(hooks, :on_filter, [%{}, socket()], default) == default
    end

    test "works with per-action tuple keys" do
      hooks = %{
        {:on_row_action_success, :delete} => fn _record, _state ->
          socket(%{flashed: true})
        end
      }

      result =
        HookRunner.apply_hook_result(
          hooks,
          {:on_row_action_success, :delete},
          [%{id: "x"}, %{}],
          socket()
        )

      assert result.assigns.flashed == true
    end
  end
end
