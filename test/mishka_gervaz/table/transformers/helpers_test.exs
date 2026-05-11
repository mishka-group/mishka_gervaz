defmodule MishkaGervaz.Table.Transformers.HelpersTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Table.Transformers.Helpers` — the
  shared compile-time helpers imported by both table and form transformers.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Transformers.Helpers
  alias MishkaGervaz.Table.Entities.Column

  describe "get_opt/4" do
    test "returns default when key not in dsl_state" do
      assert Helpers.get_opt(%{}, [:any], :nonexistent, :fallback) == :fallback
    end

    test "defaults to nil when no default passed" do
      assert Helpers.get_opt(%{}, [:any], :nonexistent) == nil
    end
  end

  describe "get_entities/2 and filter_by_type/2" do
    test "get_entities returns [] for missing path" do
      assert Helpers.get_entities(%{}, [:nonexistent]) == []
    end

    test "filter_by_type/2 keeps only matching structs" do
      col = %Column{name: :title}
      mixed = [col, %{name: :not_a_column}, "string", :atom]

      assert Helpers.filter_by_type(mixed, Column) == [col]
    end

    test "filter_by_type with no matches returns []" do
      assert Helpers.filter_by_type([%{name: :x}, "y"], Column) == []
    end
  end

  describe "safe_domain/1 + safe_domain_config/1" do
    test "safe_domain returns :error for non-resource module" do
      assert Helpers.safe_domain(SomeMod) == :error
    end

    test "safe_domain returns {:ok, domain} for a real resource" do
      assert {:ok, _} = Helpers.safe_domain(MishkaGervaz.Test.Resources.FormPost)
    end

    test "safe_domain_config returns nil for non-MishkaGervaz domain" do
      assert Helpers.safe_domain_config(Enum) == nil
    end

    test "safe_domain_config returns map for MishkaGervaz domain" do
      assert is_map(Helpers.safe_domain_config(MishkaGervaz.Test.Domain))
    end
  end

  describe "get_domain_config/1" do
    test "returns the domain's persisted config when wired" do
      config = Helpers.get_domain_config(MishkaGervaz.Test.Resources.FormPost)
      assert is_map(config)
    end

    test "returns nil when resource has no MishkaGervaz domain" do
      assert Helpers.get_domain_config(SomeMod) == nil
    end
  end

  describe "has_extension?/2" do
    test "true for an extension present on the module" do
      assert Helpers.has_extension?(
               MishkaGervaz.Test.Resources.FormPost,
               MishkaGervaz.Resource
             )
    end

    test "false for an extension that's not present" do
      refute Helpers.has_extension?(
               MishkaGervaz.Test.Resources.FormPost,
               AshOban
             )
    end

    test "false for non-modules / non-resources" do
      refute Helpers.has_extension?(SomeMod, MishkaGervaz.Resource)
    end
  end

  describe "any_set?/1" do
    test "true when at least one value is not nil" do
      assert Helpers.any_set?([nil, nil, "x"])
      assert Helpers.any_set?(["x"])
      assert Helpers.any_set?([false, nil])
    end

    test "false when all values are nil" do
      refute Helpers.any_set?([nil, nil])
      refute Helpers.any_set?([])
    end
  end

  describe "default_if_nil/2" do
    test "returns default when value is nil" do
      assert Helpers.default_if_nil(nil, :default) == :default
    end

    test "returns value when not nil (even falsy)" do
      assert Helpers.default_if_nil(false, :default) == false
      assert Helpers.default_if_nil("", :default) == ""
      assert Helpers.default_if_nil(0, :default) == 0
    end
  end

  describe "extract_nested_entity/2" do
    test "list with matching struct first → first" do
      col = %Column{name: :title}
      assert Helpers.extract_nested_entity([col, %Column{name: :body}], Column) == col
    end

    test "single matching struct → struct" do
      col = %Column{name: :title}
      assert Helpers.extract_nested_entity(col, Column) == col
    end

    test "non-matching values → nil" do
      assert Helpers.extract_nested_entity(nil, Column) == nil
      assert Helpers.extract_nested_entity(:atom, Column) == nil
      assert Helpers.extract_nested_entity([%{name: :a}], Column) == nil
    end
  end
end
