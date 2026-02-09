defmodule MishkaGervaz.Form.DSL.LayoutTest do
  @moduledoc """
  Tests for the form layout DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    WizardForm,
    TabsForm,
    MinimalForm
  }

  describe "FormPost standard layout" do
    test "mode is :standard" do
      layout = FormInfo.layout(FormPost)
      assert layout.mode == :standard
    end

    test "columns is 2" do
      layout = FormInfo.layout(FormPost)
      assert layout.columns == 2
    end

    test "responsive is true" do
      layout = FormInfo.layout(FormPost)
      assert layout.responsive == true
    end

    test "no steps" do
      layout = FormInfo.layout(FormPost)
      assert layout.steps == nil
    end

    test "navigation defaults to :sequential" do
      layout = FormInfo.layout(FormPost)
      assert layout.navigation == :sequential
    end

    test "persistence defaults to :none" do
      layout = FormInfo.layout(FormPost)
      assert layout.persistence == :none
    end
  end

  describe "WizardForm wizard layout" do
    test "mode is :wizard" do
      layout = FormInfo.layout(WizardForm)
      assert layout.mode == :wizard
    end

    test "has 3 steps" do
      steps = FormInfo.steps(WizardForm)
      assert length(steps) == 3
    end

    test "navigation is :sequential" do
      assert FormInfo.navigation(WizardForm) == :sequential
    end

    test "persistence is :ets" do
      assert FormInfo.persistence(WizardForm) == :ets
    end
  end

  describe "TabsForm tabs layout" do
    test "mode is :tabs" do
      layout = FormInfo.layout(TabsForm)
      assert layout.mode == :tabs
    end

    test "has 2 steps" do
      steps = FormInfo.steps(TabsForm)
      assert length(steps) == 2
    end

    test "navigation is :free" do
      assert FormInfo.navigation(TabsForm) == :free
    end

    test "persistence is :client_token" do
      assert FormInfo.persistence(TabsForm) == :client_token
    end
  end

  describe "step properties" do
    test "step name" do
      step = FormInfo.step(WizardForm, :details)
      assert step.name == :details
    end

    test "step groups" do
      step = FormInfo.step(WizardForm, :details)
      assert step.groups == [:basic]
    end

    test "step action" do
      step = FormInfo.step(WizardForm, :details)
      assert step.action == :validate_details
    end

    test "step summary flag" do
      review = FormInfo.step(WizardForm, :review)
      assert review.summary == true

      details = FormInfo.step(WizardForm, :details)
      assert details.summary != true
    end

    test "step visible function" do
      step = FormInfo.step(TabsForm, :settings_tab)
      assert is_function(step.visible, 1)
      assert step.visible.(%{}) == true
    end

    test "step on_enter callback" do
      step = FormInfo.step(WizardForm, :details)
      assert is_function(step.on_enter, 1)
    end

    test "step before_leave callback" do
      step = FormInfo.step(WizardForm, :details)
      assert is_function(step.before_leave, 1)
    end

    test "step after_leave callback" do
      step = FormInfo.step(WizardForm, :details)
      assert is_function(step.after_leave, 1)
    end
  end

  describe "step UI" do
    test "label" do
      step = FormInfo.step(WizardForm, :details)
      assert step.ui.label == "Details"
    end

    test "icon" do
      step = FormInfo.step(WizardForm, :details)
      assert step.ui.icon == "hero-information-circle"
    end

    test "description" do
      step = FormInfo.step(WizardForm, :details)
      assert step.ui.description == "Enter basic info"
    end

    test "class" do
      step = FormInfo.step(WizardForm, :details)
      assert step.ui.class == "step-details"
    end

    test "header_class" do
      step = FormInfo.step(WizardForm, :details)
      assert step.ui.header_class == "font-bold"
    end

    test "extra" do
      step = FormInfo.step(WizardForm, :details)
      assert step.ui.extra == %{order: 1}
    end
  end

  describe "info accessors" do
    test "steps/1 returns list for WizardForm" do
      steps = FormInfo.steps(WizardForm)
      assert is_list(steps)
      assert length(steps) == 3
    end

    test "steps/1 returns empty for FormPost (standard mode)" do
      steps = FormInfo.steps(FormPost)
      assert steps == []
    end

    test "step/2 finds by name" do
      step = FormInfo.step(WizardForm, :settings)
      assert step.name == :settings
    end

    test "step/2 returns nil for non-existent" do
      assert FormInfo.step(WizardForm, :non_existent) == nil
    end

    test "navigation/1 returns atom" do
      assert FormInfo.navigation(WizardForm) == :sequential
      assert FormInfo.navigation(TabsForm) == :free
    end

    test "persistence/1 returns atom" do
      assert FormInfo.persistence(WizardForm) == :ets
      assert FormInfo.persistence(TabsForm) == :client_token
      assert FormInfo.persistence(FormPost) == :none
    end

    test "step_groups/2 returns filtered groups" do
      groups = FormInfo.step_groups(WizardForm, :details)
      assert length(groups) == 1
      assert hd(groups).name == :basic
    end
  end

  describe "MinimalForm layout" do
    test "layout is nil" do
      assert FormInfo.layout(MinimalForm) == nil
    end

    test "steps returns empty list" do
      assert FormInfo.steps(MinimalForm) == []
    end

    test "navigation defaults to :sequential" do
      assert FormInfo.navigation(MinimalForm) == :sequential
    end

    test "persistence defaults to :none" do
      assert FormInfo.persistence(MinimalForm) == :none
    end
  end
end
