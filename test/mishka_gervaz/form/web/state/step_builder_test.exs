defmodule MishkaGervaz.Form.Web.State.StepBuilderTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.State.StepBuilder.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.StepBuilder.Default, as: StepBuilder
  alias MishkaGervaz.Resource.Info.Form, as: Info
  alias MishkaGervaz.Test.Resources.WizardForm

  describe "build/2" do
    test "returns steps with :resolved_label for a wizard resource" do
      config = Info.config(WizardForm)
      result = StepBuilder.build(config, WizardForm)

      assert is_list(result)

      for step <- result do
        assert is_map(step)
        assert Map.has_key?(step, :name)
        assert Map.has_key?(step, :resolved_label)
      end
    end

    test "returns [] for non-map config" do
      assert StepBuilder.build(nil, WizardForm) == []
      assert StepBuilder.build(:atom, WizardForm) == []
    end
  end

  describe "initial_step/1" do
    test "returns first step's name" do
      assert StepBuilder.initial_step([%{name: :a}, %{name: :b}]) == :a
    end

    test "returns nil for empty list" do
      assert StepBuilder.initial_step([]) == nil
    end
  end

  describe "initial_step_states/1" do
    test "returns %{} for empty list" do
      assert StepBuilder.initial_step_states([]) == %{}
    end

    test "first step is :active, rest are :pending" do
      result =
        StepBuilder.initial_step_states([%{name: :s1}, %{name: :s2}, %{name: :s3}])

      assert result == %{s1: :active, s2: :pending, s3: :pending}
    end

    test "single step is :active" do
      assert StepBuilder.initial_step_states([%{name: :only}]) == %{only: :active}
    end
  end

  describe "step_valid?/2" do
    test "returns true by default" do
      assert StepBuilder.step_valid?(%{name: :s}, %{})
    end
  end

  describe "override pattern" do
    test "user can override initial_step via use" do
      defmodule TestStepBuilderOverride do
        use MishkaGervaz.Form.Web.State.StepBuilder

        def initial_step([_first, second | _]), do: second.name
        def initial_step(steps), do: super(steps)
      end

      assert TestStepBuilderOverride.initial_step([%{name: :a}, %{name: :b}, %{name: :c}]) ==
               :b

      assert TestStepBuilderOverride.initial_step([%{name: :only}]) == :only
      assert TestStepBuilderOverride.initial_step([]) == nil
    end
  end
end
