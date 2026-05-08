defmodule MishkaGervaz.Form.Web.Events.StepHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.StepHandler.Default`.

  Covers the three top-level public helpers (`find_next_step/2`,
  `find_prev_step/2`, `step_exists?/2`) and the overridable predicate
  `can_advance?/2`. The `advance/2`, `go_back/2`, `goto_step/3` callbacks
  mutate socket assigns and are exercised through `events_test.exs`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.StepHandler
  alias MishkaGervaz.Form.Web.Events.StepHandler.Default

  describe "find_next_step/2" do
    test "returns the step after current" do
      assert StepHandler.find_next_step([%{name: :a}, %{name: :b}, %{name: :c}], :a) == :b
      assert StepHandler.find_next_step([%{name: :a}, %{name: :b}], :a) == :b
    end

    test "returns nil when current is last" do
      assert StepHandler.find_next_step([%{name: :a}, %{name: :b}], :b) == nil
    end

    test "returns nil when current not found" do
      assert StepHandler.find_next_step([%{name: :a}], :ghost) == nil
    end

    test "returns nil for empty list" do
      assert StepHandler.find_next_step([], :a) == nil
    end
  end

  describe "find_prev_step/2" do
    test "returns the step before current" do
      assert StepHandler.find_prev_step([%{name: :a}, %{name: :b}, %{name: :c}], :c) == :b
      assert StepHandler.find_prev_step([%{name: :a}, %{name: :b}], :b) == :a
    end

    test "returns nil when current is first" do
      assert StepHandler.find_prev_step([%{name: :a}, %{name: :b}], :a) == nil
    end

    test "returns nil when current not found" do
      assert StepHandler.find_prev_step([%{name: :a}], :ghost) == nil
    end

    test "returns nil for empty list" do
      assert StepHandler.find_prev_step([], :a) == nil
    end
  end

  describe "step_exists?/2" do
    test "true when step is in static.steps" do
      state = %{static: %{steps: [%{name: :first}, %{name: :second}]}}
      assert StepHandler.step_exists?(state, :first)
      assert StepHandler.step_exists?(state, :second)
    end

    test "false when step is not present" do
      state = %{static: %{steps: [%{name: :first}]}}
      refute StepHandler.step_exists?(state, :ghost)
    end

    test "false for empty steps" do
      state = %{static: %{steps: []}}
      refute StepHandler.step_exists?(state, :anything)
    end
  end

  describe "can_advance?/2" do
    test "default returns true regardless of inputs" do
      assert Default.can_advance?(%{}, :step1)
      assert Default.can_advance?(%{anything: :else}, :other)
    end

    test "user override surfaces" do
      defmodule TestCanAdvanceOverride do
        use MishkaGervaz.Form.Web.Events.StepHandler

        def can_advance?(%{dirty?: false}, _step), do: false
        def can_advance?(state, step), do: super(state, step)
      end

      refute TestCanAdvanceOverride.can_advance?(%{dirty?: false}, :step1)
      assert TestCanAdvanceOverride.can_advance?(%{dirty?: true}, :step1)
    end
  end
end
