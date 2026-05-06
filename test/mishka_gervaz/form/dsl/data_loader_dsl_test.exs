defmodule MishkaGervaz.Form.Dsl.DataLoaderDslTest do
  @moduledoc """
  Tests the form `data_loader` DSL section: per-sub-builder overrides
  (record/tenant/relation/hooks) and whole-module override.
  Mirrors the table-side data_loader DSL test.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: Info

  alias MishkaGervaz.Test.FormDataLoaderDsl.{
    RecordOverrideResource,
    TenantOverrideResource,
    RelationOverrideResource,
    HooksOverrideResource,
    AllSubBuildersResource,
    WholeModuleResource,
    NoOverrideResource,
    CustomRecordLoader,
    CustomTenantResolver,
    CustomRelationLoader,
    CustomHookRunner,
    CustomDataLoaderModule
  }

  describe "Info.data_loader/1 — reading DSL data_loader config" do
    test "empty map when no data_loader config is set" do
      assert Info.data_loader(NoOverrideResource) == %{}
    end

    test "returns record loader when defined" do
      assert Info.data_loader(RecordOverrideResource)[:record] == CustomRecordLoader
    end

    test "returns tenant resolver when defined" do
      assert Info.data_loader(TenantOverrideResource)[:tenant] == CustomTenantResolver
    end

    test "returns relation loader when defined" do
      assert Info.data_loader(RelationOverrideResource)[:relation] == CustomRelationLoader
    end

    test "returns hook runner when defined" do
      assert Info.data_loader(HooksOverrideResource)[:hooks] == CustomHookRunner
    end

    test "returns whole-module override when defined" do
      assert Info.data_loader(WholeModuleResource)[:module] == CustomDataLoaderModule
    end

    test "returns all sub-builders together when defined together" do
      cfg = Info.data_loader(AllSubBuildersResource)
      assert cfg[:record] == CustomRecordLoader
      assert cfg[:tenant] == CustomTenantResolver
      assert cfg[:relation] == CustomRelationLoader
      assert cfg[:hooks] == CustomHookRunner
    end

    test "nil values are stripped from the persisted config" do
      cfg = Info.data_loader(RecordOverrideResource)
      refute Map.has_key?(cfg, :tenant)
      refute Map.has_key?(cfg, :relation)
      refute Map.has_key?(cfg, :hooks)
      refute Map.has_key?(cfg, :module)
    end
  end

  describe "build_data_loader/1 transformer no-config behavior" do
    test "resource without data_loader block has no entry (returns empty map)" do
      assert Info.data_loader(NoOverrideResource) == %{}
    end
  end
end
