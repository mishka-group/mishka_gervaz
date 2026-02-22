defmodule MishkaGervaz.Form.DSL.AccessControlTest do
  @moduledoc """
  Tests for source-level access control DSL (restricted, access entity, access fn).
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    RestrictedCreateForm,
    AccessPerModeForm,
    RestrictedFnForm
  }

  describe "source restricted: true" do
    test "config stores restricted as true" do
      config = FormInfo.config(RestrictedCreateForm)
      assert config.source.restricted == true
    end

    test "access_rules is empty when only restricted is set" do
      config = FormInfo.config(RestrictedCreateForm)
      assert config.source.access_rules == %{}
    end

  end

  describe "source restricted: fn" do
    test "config stores restricted as function" do
      config = FormInfo.config(RestrictedFnForm)
      assert is_function(config.source.restricted, 1)
    end

    test "restricted fn returns true for non-master" do
      config = FormInfo.config(RestrictedFnForm)
      assert config.source.restricted.(%{master_user?: false}) == true
    end

    test "restricted fn returns false for master" do
      config = FormInfo.config(RestrictedFnForm)
      assert config.source.restricted.(%{master_user?: true}) == false
    end
  end

  describe "per-mode access entity" do
    test "access_rules has :create rule" do
      config = FormInfo.config(AccessPerModeForm)
      assert Map.has_key?(config.source.access_rules, :create)
    end

    test "create rule is restricted" do
      config = FormInfo.config(AccessPerModeForm)
      assert config.source.access_rules.create.restricted == true
    end

    test "access_rules has :update rule with condition" do
      config = FormInfo.config(AccessPerModeForm)
      rule = config.source.access_rules.update
      assert is_function(rule.condition, 1)
    end

    test "update condition allows master user" do
      config = FormInfo.config(AccessPerModeForm)
      rule = config.source.access_rules.update
      assert rule.condition.(%{master_user?: true}) == true
    end

    test "update condition allows user with can_edit?" do
      config = FormInfo.config(AccessPerModeForm)
      rule = config.source.access_rules.update
      assert rule.condition.(%{master_user?: false, can_edit?: true}) == true
    end

    test "update condition denies user without access" do
      config = FormInfo.config(AccessPerModeForm)
      rule = config.source.access_rules.update
      refute rule.condition.(%{master_user?: false})
    end

    test "source-level restricted defaults to false" do
      config = FormInfo.config(AccessPerModeForm)
      assert config.source.restricted == false
    end

  end

  describe "defaults when no access control set" do
    test "restricted defaults to false" do
      config = FormInfo.config(MishkaGervaz.Test.Resources.FormPost)
      assert config.source.restricted == false
    end

    test "access_rules defaults to empty map" do
      config = FormInfo.config(MishkaGervaz.Test.Resources.FormPost)
      assert config.source.access_rules == %{}
    end
  end
end
