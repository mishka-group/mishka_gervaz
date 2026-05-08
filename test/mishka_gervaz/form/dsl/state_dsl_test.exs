defmodule MishkaGervaz.Form.Dsl.StateDslTest do
  @moduledoc """
  Tests the form `state` DSL section: per-sub-builder overrides
  (field/group/step/presentation/access) and the whole-module override
  (`state do module ... end`). Mirrors the table-side state DSL test.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State
  alias MishkaGervaz.Resource.Info.Form, as: Info

  alias MishkaGervaz.Test.FormStateDsl.{
    FieldOverrideResource,
    GroupOverrideResource,
    StepOverrideResource,
    PresentationOverrideResource,
    AccessOverrideResource,
    AllBuildersOverrideResource,
    WholeStateOverrideResource,
    NoOverrideResource
  }

  defp master_user, do: %{id: "m-1", site_id: nil, role: :admin}
  defp tenant_user, do: %{id: "t-1", site_id: "site-abc", role: :user}
  defp super_user, do: %{id: "s-1", role: :superadmin, site_id: "any"}

  describe "Info.state/1 — reading DSL state config" do
    test "empty map when no state config is set" do
      assert Info.state(NoOverrideResource) == %{}
    end

    test "returns the field builder when defined" do
      assert Info.state(FieldOverrideResource)[:field] ==
               MishkaGervaz.Test.FormStateDsl.CustomFieldBuilder
    end

    test "returns the group builder when defined" do
      assert Info.state(GroupOverrideResource)[:group] ==
               MishkaGervaz.Test.FormStateDsl.CustomGroupBuilder
    end

    test "returns the step builder when defined" do
      assert Info.state(StepOverrideResource)[:step] ==
               MishkaGervaz.Test.FormStateDsl.CustomStepBuilder
    end

    test "returns the presentation when defined" do
      assert Info.state(PresentationOverrideResource)[:presentation] ==
               MishkaGervaz.Test.FormStateDsl.CustomPresentation
    end

    test "returns the access when defined" do
      assert Info.state(AccessOverrideResource)[:access] ==
               MishkaGervaz.Test.FormStateDsl.CustomAccess
    end

    test "returns the module when whole-state override is set" do
      assert Info.state(WholeStateOverrideResource)[:module] ==
               MishkaGervaz.Test.FormStateDsl.CustomWholeState
    end

    test "returns all sub-builders together when defined together" do
      cfg = Info.state(AllBuildersOverrideResource)
      assert cfg[:field] == MishkaGervaz.Test.FormStateDsl.CustomFieldBuilder
      assert cfg[:group] == MishkaGervaz.Test.FormStateDsl.CustomGroupBuilder
      assert cfg[:presentation] == MishkaGervaz.Test.FormStateDsl.CustomPresentation
      assert cfg[:access] == MishkaGervaz.Test.FormStateDsl.CustomAccess
    end
  end

  describe "field builder override" do
    test "custom builder receives runtime control over fields" do
      state = State.init("test-id", FieldOverrideResource, master_user())

      assert Enum.all?(state.static.fields, &Map.get(&1, :__custom_field_marker__))
    end

    test "custom field builder still produces the resource's fields" do
      state = State.init("test-id", FieldOverrideResource, master_user())

      assert Enum.any?(state.static.fields, &(&1.name == :title))
    end
  end

  describe "group builder override" do
    test "custom builder receives runtime control over groups" do
      state = State.init("test-id", GroupOverrideResource, master_user())

      assert Enum.all?(state.static.groups, &Map.get(&1, :__custom_group_marker__))
    end
  end

  describe "step builder override" do
    test "custom builder receives runtime control over steps" do
      state = State.init("test-id", StepOverrideResource, master_user())

      assert state.static.layout_mode == :wizard
      assert Enum.all?(state.static.steps, &Map.get(&1, :__custom_step_marker__))
    end
  end

  describe "presentation override" do
    test "custom presentation drives feature list" do
      state = State.init("test-id", PresentationOverrideResource, master_user())

      assert :__custom_presentation_marker__ in state.static.features
    end

    test "custom presentation drives template selection" do
      state = State.init("test-id", PresentationOverrideResource, master_user())

      assert state.static.template == MishkaGervaz.Form.Templates.Standard
    end
  end

  describe "access override" do
    test "custom access promotes superadmin to master" do
      state = State.init("test-id", AccessOverrideResource, super_user())

      assert state.master_user? == true
    end

    test "custom access still recognises master_user via site_id nil" do
      state = State.init("test-id", AccessOverrideResource, master_user())

      assert state.master_user? == true
    end

    test "custom access returns false for tenant user" do
      state = State.init("test-id", AccessOverrideResource, tenant_user())

      assert state.master_user? == false
    end
  end

  describe "all sub-builders together" do
    test "every active marker is present" do
      state = State.init("test-id", AllBuildersOverrideResource, super_user())

      assert Enum.all?(state.static.fields, &Map.get(&1, :__custom_field_marker__))
      assert Enum.all?(state.static.groups, &Map.get(&1, :__custom_group_marker__))
      assert :__custom_presentation_marker__ in state.static.features
      assert state.master_user? == true
    end
  end

  describe "whole-state module override (state do module ... end)" do
    test "init delegates to the custom module" do
      state = State.init("test-id", WholeStateOverrideResource, master_user())

      assert state.defaults == %{__whole_state_override__: true}
    end

    test "custom module still uses default builders inside default_init" do
      state = State.init("test-id", WholeStateOverrideResource, master_user())

      assert Enum.any?(state.static.fields, &(&1.name == :title))
      assert state.static.id == "test-id"
      assert state.static.resource == WholeStateOverrideResource
    end
  end

  describe "default behavior without DSL state config" do
    test "uses default builders when no config" do
      state = State.init("test-id", NoOverrideResource, master_user())

      refute Enum.any?(state.static.fields, &Map.get(&1, :__custom_field_marker__))
      refute Enum.any?(state.static.groups, &Map.get(&1, :__custom_group_marker__))
      refute :__custom_presentation_marker__ in (state.static.features || [])
    end
  end
end
