defmodule MishkaGervaz.Table.Dsl.DataLoaderDslTest do
  @moduledoc """
  Tests for DataLoader DSL configuration.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Table, as: Info

  alias MishkaGervaz.Test.DataLoader.{
    CustomPaginationResource,
    CustomQueryResource,
    CustomFullResource,
    CustomModuleResource,
    BasicResource,
    CustomPaginationHandler,
    CustomQueryBuilder,
    CustomFilterParser,
    CustomTenantResolver,
    CustomHookRunner,
    CustomRelationLoader,
    CustomDataLoaderModule
  }

  describe "DSL data_loader entity configuration" do
    test "resource with custom pagination handler returns correct config" do
      config = Info.data_loader(CustomPaginationResource)

      assert config[:pagination] == CustomPaginationHandler
      assert config[:query] == nil
      assert config[:filter_parser] == nil
      assert config[:module] == nil
    end

    test "resource with custom query builder returns correct config" do
      config = Info.data_loader(CustomQueryResource)

      assert config[:query] == CustomQueryBuilder
      assert config[:pagination] == nil
      assert config[:filter_parser] == nil
      assert config[:module] == nil
    end

    test "resource with multiple custom sub-builders returns all overrides" do
      config = Info.data_loader(CustomFullResource)

      assert config[:query] == CustomQueryBuilder
      assert config[:filter_parser] == CustomFilterParser
      assert config[:pagination] == CustomPaginationHandler
      assert config[:tenant] == CustomTenantResolver
      assert config[:hooks] == CustomHookRunner
      assert config[:relation] == CustomRelationLoader
      assert config[:module] == nil
    end

    test "resource with custom module (positional arg) returns module config" do
      config = Info.data_loader(CustomModuleResource)

      assert config[:module] == CustomDataLoaderModule
      # Sub-builder keys should be nil when module is set
      assert config[:query] == nil
      assert config[:pagination] == nil
    end

    test "resource without custom data_loader returns empty config" do
      config = Info.data_loader(BasicResource)

      assert config == %{}
    end
  end

  describe "Config transformer persists data_loader settings" do
    test "data_loader is included in persisted config" do
      config = Info.config(CustomPaginationResource)

      assert is_map(config[:data_loader])
      assert config[:data_loader][:pagination] == CustomPaginationHandler
    end

    test "full config includes data_loader with all sub-builders" do
      config = Info.config(CustomFullResource)

      assert config[:data_loader][:query] == CustomQueryBuilder
      assert config[:data_loader][:filter_parser] == CustomFilterParser
      assert config[:data_loader][:pagination] == CustomPaginationHandler
      assert config[:data_loader][:tenant] == CustomTenantResolver
      assert config[:data_loader][:hooks] == CustomHookRunner
      assert config[:data_loader][:relation] == CustomRelationLoader
    end

    test "module override is correctly persisted" do
      config = Info.config(CustomModuleResource)

      assert config[:data_loader][:module] == CustomDataLoaderModule
    end

    test "resource without data_loader has nil in config" do
      config = Info.config(BasicResource)

      # data_loader should be nil when not configured
      assert config[:data_loader] == nil
    end
  end

  describe "DSL validation" do
    test "data_loader entity can coexist with other table DSL elements" do
      config = Info.config(CustomPaginationResource)

      # Verify other DSL elements still work
      assert config[:identity][:name] == :custom_pagination_items
      assert config[:identity][:route] == "/admin/custom-pagination"
      assert config[:pagination][:page_size] == 5
      assert config[:pagination][:type] == :numbered
    end

    test "data_loader with positional arg is valid syntax" do
      config = Info.config(CustomModuleResource)

      # Should compile and have correct identity
      assert config[:identity][:name] == :custom_module_items
      assert config[:identity][:route] == "/admin/custom-module"
    end
  end
end
