defmodule MishkaGervaz.Info.DomainTableInfoTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Domain.Info.Table` accessors, focused on
  edge cases and accessors not exercised through `DomainInfo` in
  `domain_info_test.exs` — `ui_adapter_opts`, `actor_key`, `master_check`,
  and `actions` (none of those have value assertions in the existing file),
  plus nil-safety on every accessor for a domain without a `mishka_gervaz`
  block.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Domain.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Domain

  defmodule BareDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  describe "actor_key/1" do
    test "returns the configured actor on Test.Domain" do
      assert TableInfo.actor_key(Domain) == :current_user
    end

    test "defaults to :current_user when not configured" do
      assert TableInfo.actor_key(BareDomain) == :current_user
    end
  end

  describe "master_check/1" do
    test "returns the configured function on Test.Domain" do
      check = TableInfo.master_check(Domain)
      assert is_function(check, 1)
      assert check.(%{role: :admin}) == true
      assert check.(%{role: :user}) == false
    end

    test "returns nil for a domain without master_check" do
      assert TableInfo.master_check(BareDomain) == nil
    end
  end

  describe "ui_adapter_opts/1" do
    test "defaults to [] on Test.Domain (no opts configured)" do
      assert TableInfo.ui_adapter_opts(Domain) == []
    end

    test "returns [] for a domain without mishka_gervaz" do
      assert TableInfo.ui_adapter_opts(BareDomain) == []
    end
  end

  describe "actions/1" do
    test "returns the actions map on Test.Domain" do
      actions = TableInfo.actions(Domain)
      assert is_map(actions)
      assert actions.read == {:master_read, :read}
      assert actions.get == {:master_get, :read}
      assert actions.destroy == {:master_destroy, :destroy}
    end

    test "returns nil for a domain without actions" do
      assert TableInfo.actions(BareDomain) == nil
    end
  end

  describe "BareDomain — every accessor returns sensible defaults" do
    test "config returns nil" do
      assert TableInfo.config(BareDomain) == nil
    end

    test "defaults returns %{}" do
      assert TableInfo.defaults(BareDomain) == %{}
    end

    test "navigation returns nil (now lives on Domain.Info, not Domain.Info.Table)" do
      assert MishkaGervaz.Domain.Info.navigation(BareDomain) == nil
    end

    test "menu_groups returns [] (now lives on Domain.Info, not Domain.Info.Table)" do
      assert MishkaGervaz.Domain.Info.menu_groups(BareDomain) == []
    end

    test "ui_adapter falls back to Tailwind" do
      assert TableInfo.ui_adapter(BareDomain) == MishkaGervaz.UIAdapters.Tailwind
    end

    test "pagination returns nil" do
      assert TableInfo.pagination(BareDomain) == nil
    end

    test "page_size returns nil" do
      assert TableInfo.page_size(BareDomain) == nil
    end

    test "page_size_options returns nil" do
      assert TableInfo.page_size_options(BareDomain) == nil
    end

    test "max_page_size returns nil" do
      assert TableInfo.max_page_size(BareDomain) == nil
    end

    test "realtime returns nil" do
      assert TableInfo.realtime(BareDomain) == nil
    end

    test "theme returns nil" do
      assert TableInfo.theme(BareDomain) == nil
    end

    test "refresh returns nil" do
      assert TableInfo.refresh(BareDomain) == nil
    end

    test "url_sync returns nil" do
      assert TableInfo.url_sync(BareDomain) == nil
    end
  end
end
