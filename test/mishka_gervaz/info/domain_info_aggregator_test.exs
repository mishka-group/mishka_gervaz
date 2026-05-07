defmodule MishkaGervaz.Info.DomainInfoAggregatorTest do
  @moduledoc """
  Tests for `MishkaGervaz.Domain.Info` — the nested aggregator that follows
  the strict `<table|form>_<exact_name>` convention.

  These tests verify two things for each delegate:

  1. The function exists on the aggregator under the prefixed name.
  2. The aggregator returns the same value as the underlying submodule
     (`Domain.Info.Table` / `Domain.Info.Form`) — i.e. the delegate is
     wired to the right target.

  Value semantics are covered in detail elsewhere — `domain_info_test.exs`
  hits the same code through `MishkaGervaz.DomainInfo`, the table/form DSL
  tests pin the submodule behavior. Here we only assert the aggregator does
  not drift from its targets.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Domain.Info, as: DomainInfo
  alias MishkaGervaz.Domain.Info.Form, as: FormInfo
  alias MishkaGervaz.Domain.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Domain

  describe "table_* delegates route to Domain.Info.Table" do
    test "table_config" do
      assert DomainInfo.table_config(Domain) == TableInfo.config(Domain)
    end

    test "table_defaults" do
      assert DomainInfo.table_defaults(Domain) == TableInfo.defaults(Domain)
    end

    test "table_navigation" do
      assert DomainInfo.table_navigation(Domain) == TableInfo.navigation(Domain)
    end

    test "table_menu_groups" do
      assert DomainInfo.table_menu_groups(Domain) == TableInfo.menu_groups(Domain)
    end

    test "table_ui_adapter" do
      assert DomainInfo.table_ui_adapter(Domain) == TableInfo.ui_adapter(Domain)
    end

    test "table_ui_adapter_opts" do
      assert DomainInfo.table_ui_adapter_opts(Domain) == TableInfo.ui_adapter_opts(Domain)
    end

    test "table_actor_key" do
      assert DomainInfo.table_actor_key(Domain) == TableInfo.actor_key(Domain)
    end

    test "table_master_check returns the same function reference" do
      assert DomainInfo.table_master_check(Domain) == TableInfo.master_check(Domain)
    end

    test "table_actions" do
      assert DomainInfo.table_actions(Domain) == TableInfo.actions(Domain)
    end

    test "table_pagination" do
      assert DomainInfo.table_pagination(Domain) == TableInfo.pagination(Domain)
    end

    test "table_page_size" do
      assert DomainInfo.table_page_size(Domain) == TableInfo.page_size(Domain)
    end

    test "table_page_size_options" do
      assert DomainInfo.table_page_size_options(Domain) == TableInfo.page_size_options(Domain)
    end

    test "table_max_page_size" do
      assert DomainInfo.table_max_page_size(Domain) == TableInfo.max_page_size(Domain)
    end

    test "table_realtime" do
      assert DomainInfo.table_realtime(Domain) == TableInfo.realtime(Domain)
    end

    test "table_theme" do
      assert DomainInfo.table_theme(Domain) == TableInfo.theme(Domain)
    end

    test "table_refresh" do
      assert DomainInfo.table_refresh(Domain) == TableInfo.refresh(Domain)
    end

    test "table_url_sync" do
      assert DomainInfo.table_url_sync(Domain) == TableInfo.url_sync(Domain)
    end
  end

  describe "form_* delegates route to Domain.Info.Form" do
    test "form_config" do
      assert DomainInfo.form_config(Domain) == FormInfo.config(Domain)
    end

    test "form_defaults" do
      assert DomainInfo.form_defaults(Domain) == FormInfo.defaults(Domain)
    end

    test "form_ui_adapter" do
      assert DomainInfo.form_ui_adapter(Domain) == FormInfo.ui_adapter(Domain)
    end

    test "form_ui_adapter_opts" do
      assert DomainInfo.form_ui_adapter_opts(Domain) == FormInfo.ui_adapter_opts(Domain)
    end

    test "form_actor_key" do
      assert DomainInfo.form_actor_key(Domain) == FormInfo.actor_key(Domain)
    end

    test "form_master_check returns the same function reference" do
      assert DomainInfo.form_master_check(Domain) == FormInfo.master_check(Domain)
    end

    test "form_actions" do
      assert DomainInfo.form_actions(Domain) == FormInfo.actions(Domain)
    end

    test "form_theme" do
      assert DomainInfo.form_theme(Domain) == FormInfo.theme(Domain)
    end

    test "form_layout" do
      assert DomainInfo.form_layout(Domain) == FormInfo.layout(Domain)
    end

    test "form_template" do
      assert DomainInfo.form_template(Domain) == FormInfo.template(Domain)
    end

    test "form_features" do
      assert DomainInfo.form_features(Domain) == FormInfo.features(Domain)
    end

    test "form_submit" do
      assert DomainInfo.form_submit(Domain) == FormInfo.submit(Domain)
    end
  end

  describe "naming convention coverage" do
    test "every public Domain.Info.Table function has a table_<name> delegate" do
      table_funcs =
        TableInfo.__info__(:functions)
        |> Enum.map(&elem(&1, 0))
        |> Enum.reject(&match?("_" <> _, Atom.to_string(&1)))
        |> Enum.reject(&String.starts_with?(Atom.to_string(&1), "mishka_gervaz_"))
        |> MapSet.new()

      delegate_targets =
        DomainInfo.__info__(:functions)
        |> Enum.map(&elem(&1, 0))
        |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "table_"))
        |> Enum.map(fn name ->
          name |> Atom.to_string() |> String.replace_prefix("table_", "") |> String.to_atom()
        end)
        |> MapSet.new()

      missing = MapSet.difference(table_funcs, delegate_targets)
      assert MapSet.size(missing) == 0, "Missing table_* delegates: #{inspect(missing)}"
    end

    test "every public Domain.Info.Form function has a form_<name> delegate" do
      form_funcs =
        FormInfo.__info__(:functions)
        |> Enum.map(&elem(&1, 0))
        |> Enum.reject(&match?("_" <> _, Atom.to_string(&1)))
        |> Enum.reject(&String.starts_with?(Atom.to_string(&1), "mishka_gervaz_"))
        |> MapSet.new()

      delegate_targets =
        DomainInfo.__info__(:functions)
        |> Enum.map(&elem(&1, 0))
        |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "form_"))
        |> Enum.map(fn name ->
          name |> Atom.to_string() |> String.replace_prefix("form_", "") |> String.to_atom()
        end)
        |> MapSet.new()

      missing = MapSet.difference(form_funcs, delegate_targets)
      assert MapSet.size(missing) == 0, "Missing form_* delegates: #{inspect(missing)}"
    end
  end
end
