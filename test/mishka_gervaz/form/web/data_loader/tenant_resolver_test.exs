defmodule MishkaGervaz.Form.Web.DataLoader.TenantResolverTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.DataLoader.TenantResolver.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.DataLoader.TenantResolver.Default, as: TenantResolver
  alias MishkaGervaz.Form.Web.State

  defp build_state(attrs) do
    attrs = Map.new(attrs)

    static =
      Map.merge(%{access: MishkaGervaz.Form.Web.State.Access.Default}, attrs[:static] || %{})

    %State{
      static: struct!(MishkaGervaz.Form.Web.State.Static, Map.put_new(static, :resource, nil)),
      current_user: attrs[:current_user],
      master_user?: Map.get(attrs, :master_user?, false),
      mode: :create,
      current_step: nil,
      step_states: %{},
      wizard_history: [],
      form: nil,
      loading: :loaded,
      errors: %{},
      form_errors: [],
      field_values: %{},
      relation_options: %{},
      combobox_options: %{},
      upload_state: %{},
      existing_files: %{},
      dirty?: false,
      defaults: nil,
      preload_aliases: %{},
      dismissed_notices: MapSet.new()
    }
  end

  describe "get_tenant/1" do
    test "returns nil for master users (regardless of user shape)" do
      state = build_state(master_user?: true, current_user: %{site_id: "ignored"})
      assert TenantResolver.get_tenant(state) == nil
    end

    test "returns user's site_id for tenant users" do
      state = build_state(master_user?: false, current_user: %{site_id: "site-uuid"})
      assert TenantResolver.get_tenant(state) == "site-uuid"
    end

    test "returns nil when current_user is nil" do
      state = build_state(master_user?: false, current_user: nil)
      assert TenantResolver.get_tenant(state) == nil
    end
  end

  describe "override pattern" do
    test "user can override get_tenant via use" do
      defmodule TestTenantOverride do
        use MishkaGervaz.Form.Web.DataLoader.TenantResolver

        def get_tenant(%{master_user?: true}), do: nil

        def get_tenant(%{current_user: %{org_id: org}}) when not is_nil(org),
          do: org

        def get_tenant(state), do: super(state)
      end

      master = %{master_user?: true, current_user: %{org_id: "ignored"}}
      assert TestTenantOverride.get_tenant(master) == nil

      org_user = %{master_user?: false, current_user: %{org_id: "acme"}}
      assert TestTenantOverride.get_tenant(org_user) == "acme"
    end
  end
end
