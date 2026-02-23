defmodule MishkaGervaz.Form.Web.ModeAllowedTest do
  @moduledoc """
  Tests for `MishkaGervaz.Form.Web.State.Helpers.mode_allowed?/3`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.Helpers

  @master_state %{master_user?: true}
  @tenant_state %{master_user?: false}

  describe "mode_allowed? with nil source" do
    test "always returns true" do
      assert Helpers.mode_allowed?(nil, :create, @master_state)
      assert Helpers.mode_allowed?(nil, :create, @tenant_state)
      assert Helpers.mode_allowed?(nil, :update, @tenant_state)
    end
  end

  describe "mode_allowed? with per-mode access_rules" do
    test "restricted rule blocks non-master" do
      source = %{
        restricted: false,
        access_rules: %{create: %{restricted: true, condition: nil}}
      }

      refute Helpers.mode_allowed?(source, :create, @tenant_state)
      assert Helpers.mode_allowed?(source, :create, @master_state)
    end

    test "condition function controls access" do
      source = %{
        restricted: false,
        access_rules: %{
          update: %{restricted: false, condition: fn state -> state[:can_edit?] == true end}
        }
      }

      refute Helpers.mode_allowed?(source, :update, %{master_user?: false})
      assert Helpers.mode_allowed?(source, :update, %{master_user?: false, can_edit?: true})
    end

    test "unrestricted rule with no condition allows access" do
      source = %{
        restricted: false,
        access_rules: %{create: %{restricted: false, condition: nil}}
      }

      assert Helpers.mode_allowed?(source, :create, @tenant_state)
    end

    test "mode without rule falls through to source restricted" do
      source = %{
        restricted: true,
        access_rules: %{create: %{restricted: true, condition: nil}}
      }

      refute Helpers.mode_allowed?(source, :update, @tenant_state)
      assert Helpers.mode_allowed?(source, :update, @master_state)
    end
  end

  describe "mode_allowed? with source-level restricted" do
    test "restricted true blocks non-master on all modes" do
      source = %{restricted: true, access_rules: %{}}

      refute Helpers.mode_allowed?(source, :create, @tenant_state)
      refute Helpers.mode_allowed?(source, :update, @tenant_state)
      assert Helpers.mode_allowed?(source, :create, @master_state)
      assert Helpers.mode_allowed?(source, :update, @master_state)
    end

    test "restricted fn evaluated for each call" do
      source = %{
        restricted: fn state -> not state.master_user? end,
        access_rules: %{}
      }

      refute Helpers.mode_allowed?(source, :create, @tenant_state)
      assert Helpers.mode_allowed?(source, :create, @master_state)
    end
  end

  describe "mode_allowed? with access_gate fn/2 (style C)" do
    test "global gate controls both modes" do
      gate = fn mode, state ->
        case mode do
          :create -> state.master_user?
          :update -> true
        end
      end

      source = %{restricted: false, access_rules: %{}, access_gate: gate}

      refute Helpers.mode_allowed?(source, :create, @tenant_state)
      assert Helpers.mode_allowed?(source, :create, @master_state)
      assert Helpers.mode_allowed?(source, :update, @tenant_state)
      assert Helpers.mode_allowed?(source, :update, @master_state)
    end

    test "per-mode rules take priority over global gate" do
      gate = fn _mode, _state -> false end

      source = %{
        restricted: false,
        access_rules: %{create: %{restricted: false, condition: nil}},
        access_gate: gate
      }

      assert Helpers.mode_allowed?(source, :create, @tenant_state)
      refute Helpers.mode_allowed?(source, :update, @tenant_state)
    end
  end

  describe "mode_allowed? with no access control" do
    test "allows everything" do
      source = %{restricted: false, access_rules: %{}}

      assert Helpers.mode_allowed?(source, :create, @tenant_state)
      assert Helpers.mode_allowed?(source, :update, @tenant_state)
      assert Helpers.mode_allowed?(source, :create, @master_state)
      assert Helpers.mode_allowed?(source, :update, @master_state)
    end
  end
end
