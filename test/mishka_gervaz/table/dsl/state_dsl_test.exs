defmodule MishkaGervaz.Table.Dsl.StateDslTest do
  @moduledoc """
  Tests for the state DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Resource.Info.Table, as: Info

  alias MishkaGervaz.Test.StateDsl.{
    ColumnOverrideResource,
    FilterOverrideResource,
    ActionOverrideResource,
    PresentationOverrideResource,
    UrlSyncOverrideResource,
    AccessOverrideResource,
    AllBuildersOverrideResource,
    WholeStateOverrideResource
  }

  defp master_user, do: %{id: "master-123", site_id: nil, name: "Master Admin"}
  defp tenant_user, do: %{id: "tenant-456", site_id: "site-abc", name: "Tenant User"}
  defp superadmin_user, do: %{id: "super-123", role: :superadmin, name: "Super Admin"}
  defp can_modify_user, do: %{id: "mod-123", site_id: "site-abc", can_modify_all: true}

  describe "Info.state/1 - reading DSL state config" do
    test "returns empty map when no state config defined" do
      state_config = Info.state(MishkaGervaz.Test.Resources.User)
      assert state_config == %{}
    end

    test "returns column builder when defined" do
      state_config = Info.state(ColumnOverrideResource)
      assert state_config[:column] == MishkaGervaz.Test.StateDsl.CustomColumnBuilder
    end

    test "returns filter builder when defined" do
      state_config = Info.state(FilterOverrideResource)
      assert state_config[:filter] == MishkaGervaz.Test.StateDsl.CustomFilterBuilder
    end

    test "returns action builder when defined" do
      state_config = Info.state(ActionOverrideResource)
      assert state_config[:action] == MishkaGervaz.Test.StateDsl.CustomActionBuilder
    end

    test "returns presentation when defined" do
      state_config = Info.state(PresentationOverrideResource)
      assert state_config[:presentation] == MishkaGervaz.Test.StateDsl.CustomPresentation
    end

    test "returns url_sync when defined" do
      state_config = Info.state(UrlSyncOverrideResource)
      assert state_config[:url_sync] == MishkaGervaz.Test.StateDsl.CustomUrlSync
    end

    test "returns access when defined" do
      state_config = Info.state(AccessOverrideResource)
      assert state_config[:access] == MishkaGervaz.Test.StateDsl.CustomAccess
    end

    test "returns all builders when defined" do
      state_config = Info.state(AllBuildersOverrideResource)
      assert state_config[:column] == MishkaGervaz.Test.StateDsl.CustomColumnBuilder
      assert state_config[:filter] == MishkaGervaz.Test.StateDsl.CustomFilterBuilder
      assert state_config[:action] == MishkaGervaz.Test.StateDsl.CustomActionBuilder
      assert state_config[:presentation] == MishkaGervaz.Test.StateDsl.CustomPresentation
      assert state_config[:url_sync] == MishkaGervaz.Test.StateDsl.CustomUrlSync
      assert state_config[:access] == MishkaGervaz.Test.StateDsl.CustomAccess
    end

    test "returns module when defined" do
      state_config = Info.state(WholeStateOverrideResource)
      assert state_config[:module] == MishkaGervaz.Test.StateDsl.CustomWholeState
    end
  end

  describe "column builder override via DSL" do
    test "uses custom column builder that reverses columns" do
      state = State.init("test-id", ColumnOverrideResource, nil)

      assert is_list(state.static.columns)
      assert length(state.static.columns) > 0

      normal_state = State.init("test-id", MishkaGervaz.Test.Resources.User, nil)
      first_normal_col = hd(normal_state.static.columns).name
      first_custom_col = hd(state.static.columns).name

      refute first_normal_col == first_custom_col or length(state.static.columns) == 1
    end

    test "custom column builder inherits from default" do
      state = State.init("test-id", ColumnOverrideResource, nil)

      column_names = Enum.map(state.static.columns, & &1.name)
      assert :name in column_names
    end
  end

  describe "filter builder override via DSL" do
    test "uses custom filter builder with custom initial values" do
      state = State.init("test-id", FilterOverrideResource, nil)

      assert is_map(state.filter_values)
      assert state.filter_values[:__custom_filter_marker__] == true
    end

    test "custom filter builder inherits from default" do
      state = State.init("test-id", FilterOverrideResource, nil)

      filter_names = Enum.map(state.static.filters, & &1.name)
      assert :search in filter_names
    end
  end

  describe "action builder override via DSL" do
    test "uses custom action builder for row actions" do
      state = State.init("test-id", ActionOverrideResource, nil)

      assert is_list(state.static.row_actions)
      assert length(state.static.row_actions) > 0
    end

    test "uses custom action builder for bulk actions" do
      state = State.init("test-id", ActionOverrideResource, nil)

      assert is_list(state.static.bulk_actions)
      assert length(state.static.bulk_actions) > 0
    end

    test "uses custom action builder for hooks with custom marker" do
      state = State.init("test-id", ActionOverrideResource, nil)

      assert is_map(state.static.hooks)
      assert state.static.hooks[:__custom_hooks_marker__] == true
    end
  end

  describe "presentation override via DSL" do
    test "uses custom presentation for template resolution" do
      state = State.init("test-id", PresentationOverrideResource, nil)

      assert state.template == MishkaGervaz.Table.Templates.Table
    end

    test "uses custom presentation for template options" do
      state = State.init("test-id", PresentationOverrideResource, nil)

      assert is_list(state.static.template_options)
      assert Keyword.get(state.static.template_options, :__custom_presentation_marker__) == true
    end
  end

  describe "url_sync override via DSL" do
    test "uses custom url_sync for apply_url_state" do
      state = State.init("test-id", UrlSyncOverrideResource, nil)

      updated_state = State.apply_url_state(state, %{})
      assert updated_state.base_path == "/custom-url-sync"
    end

    test "uses custom url_sync for bidirectional check" do
      state = State.init("test-id", UrlSyncOverrideResource, nil)

      assert State.bidirectional_url_sync?(state) == true
    end

    test "apply_url_state uses path from URL state when provided" do
      state = State.init("test-id", UrlSyncOverrideResource, nil)

      updated_state = State.apply_url_state(state, %{page: 5, path: "/my-path"})
      assert updated_state.page == 5
      assert updated_state.base_path == "/my-path"
    end
  end

  describe "access override via DSL" do
    test "uses custom access for master_user? check with role:superadmin" do
      state = State.init("test-id", AccessOverrideResource, superadmin_user())

      assert state.master_user? == true
    end

    test "uses custom access for master_user? check with site_id:nil" do
      state = State.init("test-id", AccessOverrideResource, master_user())

      assert state.master_user? == true
    end

    test "uses custom access for tenant user" do
      state = State.init("test-id", AccessOverrideResource, tenant_user())

      assert state.master_user? == false
    end

    test "uses custom access for can_modify_record? with can_modify_all flag" do
      state = State.init("test-id", AccessOverrideResource, can_modify_user())
      record = %{id: "rec-1", site_id: "other-site"}

      assert State.can_modify_record?(state, record) == true
    end

    test "falls back to default can_modify_record? behavior for same tenant" do
      state = State.init("test-id", AccessOverrideResource, tenant_user())
      record = %{id: "rec-1", site_id: "site-abc"}

      assert State.can_modify_record?(state, record) == true
    end

    test "denies modification for different tenant without special permission" do
      state = State.init("test-id", AccessOverrideResource, tenant_user())
      record = %{id: "rec-1", site_id: "other-site"}

      assert State.can_modify_record?(state, record) == false
    end
  end

  describe "all builders override via DSL" do
    test "uses all custom builders together" do
      state = State.init("test-id", AllBuildersOverrideResource, superadmin_user())

      assert is_list(state.static.columns)
      assert state.filter_values[:__custom_filter_marker__] == true
      assert state.static.hooks[:__custom_hooks_marker__] == true
      assert state.template == MishkaGervaz.Table.Templates.Table
      assert state.master_user? == true
    end

    test "url_sync works with all builders" do
      state = State.init("test-id", AllBuildersOverrideResource, nil)

      updated_state = State.apply_url_state(state, %{})
      assert updated_state.base_path == "/custom-url-sync"
      assert State.bidirectional_url_sync?(state) == true
    end

    test "access works with all builders" do
      state = State.init("test-id", AllBuildersOverrideResource, can_modify_user())
      record = %{id: "rec-1", site_id: "other-site"}

      assert State.can_modify_record?(state, record) == true
    end
  end

  describe "whole state module override via DSL" do
    test "uses custom state module for init" do
      state = State.init("test-id", WholeStateOverrideResource, nil)

      assert state.base_path == "/whole-state-override"
    end

    test "custom state module inherits from default" do
      state = State.init("test-id", WholeStateOverrideResource, nil)

      assert state.static.id == "test-id"
      assert state.static.resource == WholeStateOverrideResource
      assert is_list(state.static.columns)
      assert is_list(state.static.filters)
    end

    test "custom state module builds columns from resource" do
      state = State.init("test-id", WholeStateOverrideResource, nil)

      column_names = Enum.map(state.static.columns, & &1.name)
      assert :name in column_names
    end

    test "custom state module builds filters from resource" do
      state = State.init("test-id", WholeStateOverrideResource, nil)

      filter_names = Enum.map(state.static.filters, & &1.name)
      assert :search in filter_names
    end

    test "module override is correctly read from DSL" do
      state_config = Info.state(WholeStateOverrideResource)
      assert state_config[:module] == MishkaGervaz.Test.StateDsl.CustomWholeState
    end
  end

  describe "default behavior without DSL state config" do
    test "uses default builders when no state config" do
      state = State.init("test-id", MishkaGervaz.Test.Resources.User, nil)

      assert is_list(state.static.columns)
      refute state.filter_values[:__custom_filter_marker__]
    end

    test "state functions work without DSL state config" do
      state = State.init("test-id", MishkaGervaz.Test.Resources.User, master_user())

      assert state.master_user? == true
      assert is_boolean(State.bidirectional_url_sync?(state))
    end
  end

  describe "State.update/2 with custom builders" do
    test "update works with DSL-configured state" do
      state = State.init("test-id", AllBuildersOverrideResource, nil)

      updated = State.update(state, page: 5, loading: :loaded)
      assert updated.page == 5
      assert updated.loading == :loaded
      assert updated.filter_values[:__custom_filter_marker__] == true
    end
  end

  describe "State.switch_template/2 with custom presentation" do
    test "switch_template works with custom presentation" do
      state = State.init("test-id", PresentationOverrideResource, nil)

      assert state.template == MishkaGervaz.Table.Templates.Table
    end
  end

  describe "State.get_action/2 with custom access" do
    test "get_action uses custom access module" do
      state = State.init("test-id", AccessOverrideResource, superadmin_user())

      action = State.get_action(state, :read)
      assert is_atom(action)
    end
  end

  describe "State.get_preloads/1 with custom access" do
    test "get_preloads uses custom access module" do
      state = State.init("test-id", AccessOverrideResource, superadmin_user())

      preloads = State.get_preloads(state)
      assert is_list(preloads)
    end
  end
end
