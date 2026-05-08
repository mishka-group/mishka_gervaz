defmodule MishkaGervaz.Form.Web.State.AccessTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.State.Access.Default`.

  Pins the four overridable callbacks so a regression in any of them
  surfaces here, not via a hard-to-localize symptom in `state_test.exs`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.Access.Default, as: Access
  alias MishkaGervaz.Test.Resources.FormPost

  describe "master_user?/1" do
    test "true when user has site_id: nil" do
      assert Access.master_user?(%{id: 1, site_id: nil})
    end

    test "false when user has a site_id" do
      refute Access.master_user?(%{id: 1, site_id: "uuid"})
    end

    test "false for nil" do
      refute Access.master_user?(nil)
    end

    test "false for map without site_id" do
      refute Access.master_user?(%{id: 1})
    end
  end

  describe "get_action/3" do
    test "returns the master action when master_user? is true" do
      assert Access.get_action(FormPost, :create, true) == :master_create
    end

    test "returns the tenant action when master_user? is false" do
      assert Access.get_action(FormPost, :create, false) == :create
    end

    test "delegates to Info.action_for/3 for read/update too" do
      assert is_atom(Access.get_action(FormPost, :read, true))
      assert is_atom(Access.get_action(FormPost, :update, true))
    end
  end

  describe "get_preloads/2" do
    test "returns a list" do
      assert is_list(Access.get_preloads(FormPost, true))
      assert is_list(Access.get_preloads(FormPost, false))
    end
  end

  describe "get_tenant/1" do
    test "returns nil when user is nil" do
      assert Access.get_tenant(nil) == nil
    end

    test "returns nil when user has no site_id key" do
      assert Access.get_tenant(%{id: 1}) == nil
    end

    test "returns user.site_id" do
      assert Access.get_tenant(%{id: 1, site_id: "site-uuid"}) == "site-uuid"
    end

    test "returns nil for master user (site_id: nil)" do
      assert Access.get_tenant(%{id: 1, site_id: nil}) == nil
    end
  end

  describe "override pattern" do
    test "user can override master_user? via use" do
      defmodule TestAccessOverride do
        use MishkaGervaz.Form.Web.State.Access

        def master_user?(%{flag: :always}), do: true
        def master_user?(user), do: super(user)
      end

      assert TestAccessOverride.master_user?(%{flag: :always})
      assert TestAccessOverride.master_user?(%{site_id: nil})
      refute TestAccessOverride.master_user?(%{site_id: "uuid"})
    end
  end
end
