defmodule MishkaGervaz.Table.Behaviours.TypeRegistryTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Table.Behaviours.TypeRegistry` — the
  shared macro `use`-d by every column / filter / action / field
  registry.

  Covers both invocation formats (simple map of `name => module` and
  the tuple form `name => {module, [ash_types]}`), the auto-generated
  callbacks (`get/1`, `get_or_passthrough/1`, `builtin?/1`,
  `builtin_types/0`, `default/0`, `infer_from_ash_type/1`), and the
  helper functions `normalize_builtin/1` + `lookup_ash_type/3`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Behaviours.TypeRegistry

  defmodule SimpleRegistryFixture do
    @moduledoc false
    use TypeRegistry,
      builtin: %{
        text: TypeRegistryTest.TextMod,
        select: TypeRegistryTest.SelectMod
      },
      default: TypeRegistryTest.TextMod
  end

  defmodule TupleRegistryFixture do
    @moduledoc false
    use TypeRegistry,
      builtin: %{
        text: {TypeRegistryTest.TextMod, [Ash.Type.String]},
        boolean: {TypeRegistryTest.BoolMod, [Ash.Type.Boolean]},
        number: {TypeRegistryTest.NumberMod, [Ash.Type.Integer, Ash.Type.Float, Ash.Type.Decimal]}
      },
      default: TypeRegistryTest.TextMod
  end

  describe "get/1" do
    test "returns module for registered atom" do
      assert SimpleRegistryFixture.get(:text) == TypeRegistryTest.TextMod
      assert SimpleRegistryFixture.get(:select) == TypeRegistryTest.SelectMod
    end

    test "returns nil for unknown atom" do
      assert SimpleRegistryFixture.get(:nonexistent) == nil
    end
  end

  describe "get_or_passthrough/1" do
    test "returns built-in module for registered atom" do
      assert SimpleRegistryFixture.get_or_passthrough(:text) == TypeRegistryTest.TextMod
    end

    test "returns atom as-is for unknown atoms (custom-module passthrough)" do
      assert SimpleRegistryFixture.get_or_passthrough(:nope) == :nope
      assert SimpleRegistryFixture.get_or_passthrough(MyApp.Custom) == MyApp.Custom
    end
  end

  describe "builtin?/1" do
    test "true for registered types" do
      assert SimpleRegistryFixture.builtin?(:text)
      assert SimpleRegistryFixture.builtin?(:select)
    end

    test "false for unknown types" do
      refute SimpleRegistryFixture.builtin?(:nope)
    end
  end

  describe "builtin_types/0" do
    test "lists every registered atom" do
      types = SimpleRegistryFixture.builtin_types()
      assert :text in types
      assert :select in types
      assert length(types) == 2
    end
  end

  describe "default/0" do
    test "returns the configured default module" do
      assert SimpleRegistryFixture.default() == TypeRegistryTest.TextMod
    end
  end

  describe "tuple format — infer_from_ash_type/1" do
    test "returns default when attribute is nil" do
      assert TupleRegistryFixture.infer_from_ash_type(nil) == TypeRegistryTest.TextMod
    end

    test "maps Ash.Type.String → text module" do
      assert TupleRegistryFixture.infer_from_ash_type(%{type: Ash.Type.String}) ==
               TypeRegistryTest.TextMod
    end

    test "maps Ash.Type.Boolean → boolean module" do
      assert TupleRegistryFixture.infer_from_ash_type(%{type: Ash.Type.Boolean}) ==
               TypeRegistryTest.BoolMod
    end

    test "every Ash numeric type maps to the same number module" do
      for t <- [Ash.Type.Integer, Ash.Type.Float, Ash.Type.Decimal] do
        assert TupleRegistryFixture.infer_from_ash_type(%{type: t}) == TypeRegistryTest.NumberMod
      end
    end

    test "unknown Ash type → default" do
      assert TupleRegistryFixture.infer_from_ash_type(%{type: SomeUnknown.AshType}) ==
               TypeRegistryTest.TextMod
    end
  end

  describe "normalize_builtin/1" do
    test "simple (atom => module) format → modules only, empty ash_mappings" do
      assert TypeRegistry.normalize_builtin(%{a: ModA, b: ModB}) ==
               {%{a: ModA, b: ModB}, []}
    end

    test "tuple (atom => {module, [ash_types]}) format → builds the lookup list" do
      assert {modules, mappings} =
               TypeRegistry.normalize_builtin(%{
                 a: {ModA, [Ash.Type.String, Ash.Type.Atom]},
                 b: {ModB, [Ash.Type.Boolean]}
               })

      assert modules == %{a: ModA, b: ModB}
      assert {Ash.Type.String, ModA} in mappings
      assert {Ash.Type.Atom, ModA} in mappings
      assert {Ash.Type.Boolean, ModB} in mappings
    end

    test "mixed simple + tuple entries" do
      assert {modules, mappings} =
               TypeRegistry.normalize_builtin(%{
                 a: ModA,
                 b: {ModB, [Ash.Type.Boolean]}
               })

      assert modules == %{a: ModA, b: ModB}
      assert mappings == [{Ash.Type.Boolean, ModB}]
    end
  end

  describe "lookup_ash_type/3" do
    test "finds matching type via the mappings list" do
      mappings = [{Ash.Type.String, ModA}, {Ash.Type.Boolean, ModB}]

      assert TypeRegistry.lookup_ash_type(Ash.Type.String, mappings, :default) == ModA
      assert TypeRegistry.lookup_ash_type(Ash.Type.Boolean, mappings, :default) == ModB
    end

    test "falls back to default for unmapped type" do
      mappings = [{Ash.Type.String, ModA}]
      assert TypeRegistry.lookup_ash_type(Ash.Type.Boolean, mappings, :fallback) == :fallback
    end

    test "{:array, _} → :__array__ mapping" do
      mappings = [{:__array__, ArrayMod}]
      assert TypeRegistry.lookup_ash_type({:array, :string}, mappings, :default) == ArrayMod
    end

    test "{:array, _} without :__array__ mapping → default" do
      assert TypeRegistry.lookup_ash_type({:array, :int}, [], :default) == :default
    end
  end
end
