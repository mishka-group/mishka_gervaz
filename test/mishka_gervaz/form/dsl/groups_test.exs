defmodule MishkaGervaz.Form.DSL.GroupsTest do
  @moduledoc """
  Tests for the form groups DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    WizardForm,
    MinimalForm
  }

  describe "group count" do
    test "FormPost has 2 groups" do
      groups = FormInfo.groups(FormPost)
      assert length(groups) == 2
    end

    test "WizardForm has 3 groups" do
      groups = FormInfo.groups(WizardForm)
      assert length(groups) == 3
    end

    test "MinimalForm has no groups" do
      groups = FormInfo.groups(MinimalForm)
      assert groups == []
    end
  end

  describe "group fields" do
    test "general group has correct fields" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.fields == [:title, :content, :status]
    end

    test "settings group has correct fields" do
      groups = FormInfo.groups(FormPost)
      settings = Enum.find(groups, &(&1.name == :settings))
      assert settings.fields == [:priority, :featured, :metadata]
    end
  end

  describe "group options" do
    test "collapsible" do
      groups = FormInfo.groups(FormPost)
      settings = Enum.find(groups, &(&1.name == :settings))
      assert settings.collapsible == true
    end

    test "collapsed" do
      groups = FormInfo.groups(FormPost)
      settings = Enum.find(groups, &(&1.name == :settings))
      assert settings.collapsed == true
    end

    test "position" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.position == :first
    end

    test "visible defaults to true" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.visible == true
    end

    test "restricted defaults to false" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.restricted == false
    end
  end

  describe "group UI" do
    test "label" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.ui.label == "General"
    end

    test "icon" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.ui.icon == "hero-pencil"
    end

    test "description" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.ui.description == "Core fields"
    end

    test "class" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.ui.class == "border p-4"
    end

    test "header_class" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.ui.header_class == "text-lg font-bold"
    end

    test "extra" do
      groups = FormInfo.groups(FormPost)
      general = Enum.find(groups, &(&1.name == :general))
      assert general.ui.extra == %{custom: true}
    end
  end
end
