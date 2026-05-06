defmodule MishkaGervaz.Form.Dsl.EventsDslTest do
  @moduledoc """
  Tests the form `events` DSL section: per-handler overrides and the
  whole-module override (`events MyMod`). Mirrors the table-side events DSL test.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: Info

  alias MishkaGervaz.Test.FormEventsDsl.{
    SanitizationOverrideResource,
    ValidationOverrideResource,
    SubmitOverrideResource,
    StepOverrideResource,
    UploadOverrideResource,
    RelationOverrideResource,
    HooksOverrideResource,
    AllHandlersResource,
    WholeModuleResource,
    NoOverrideResource
  }

  alias MishkaGervaz.Test.FormEventsDsl.{
    CustomSanitizationHandler,
    CustomValidationHandler,
    CustomSubmitHandler,
    CustomStepHandler,
    CustomUploadHandler,
    CustomRelationHandler,
    CustomHookRunner,
    CustomEventsModule
  }

  describe "Info.events/1 — reading DSL events config" do
    test "empty map when no events config is set" do
      assert Info.events(NoOverrideResource) == %{}
    end

    test "returns sanitization handler when defined" do
      assert Info.events(SanitizationOverrideResource)[:sanitization] ==
               CustomSanitizationHandler
    end

    test "returns validation handler when defined" do
      assert Info.events(ValidationOverrideResource)[:validation] == CustomValidationHandler
    end

    test "returns submit handler when defined" do
      assert Info.events(SubmitOverrideResource)[:submit] == CustomSubmitHandler
    end

    test "returns step handler when defined" do
      assert Info.events(StepOverrideResource)[:step] == CustomStepHandler
    end

    test "returns upload handler when defined" do
      assert Info.events(UploadOverrideResource)[:upload] == CustomUploadHandler
    end

    test "returns relation handler when defined" do
      assert Info.events(RelationOverrideResource)[:relation] == CustomRelationHandler
    end

    test "returns hooks handler when defined" do
      assert Info.events(HooksOverrideResource)[:hooks] == CustomHookRunner
    end

    test "returns whole-module override when defined" do
      assert Info.events(WholeModuleResource)[:module] == CustomEventsModule
    end

    test "returns all handlers together when defined together" do
      cfg = Info.events(AllHandlersResource)
      assert cfg[:sanitization] == CustomSanitizationHandler
      assert cfg[:validation] == CustomValidationHandler
      assert cfg[:submit] == CustomSubmitHandler
      assert cfg[:step] == CustomStepHandler
      assert cfg[:upload] == CustomUploadHandler
      assert cfg[:relation] == CustomRelationHandler
      assert cfg[:hooks] == CustomHookRunner
    end

    test "nil values are stripped from the persisted config" do
      cfg = Info.events(SanitizationOverrideResource)
      refute Map.has_key?(cfg, :validation)
      refute Map.has_key?(cfg, :submit)
      refute Map.has_key?(cfg, :step)
      refute Map.has_key?(cfg, :upload)
      refute Map.has_key?(cfg, :relation)
      refute Map.has_key?(cfg, :hooks)
      refute Map.has_key?(cfg, :module)
    end
  end

  describe "build_events/1 transformer no-config behavior" do
    test "resource without events block has no events key (or nil)" do
      cfg = Info.events(NoOverrideResource)
      assert cfg == %{}
    end
  end
end
