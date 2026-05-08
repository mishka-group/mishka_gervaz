defmodule MishkaGervaz.Form.Entities.SchemaTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Entities.Schema` — the shared
  `:visible` / `:restricted` schema fragments merged into 7 entities'
  `@opt_schema` lists.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Entities.Schema

  describe "visible_key/0" do
    test "returns a keyword with :visible" do
      assert [{:visible, opts}] = Schema.visible_key()
      assert opts[:type] == {:or, [:boolean, {:fun, 1}]}
      assert opts[:default] == true
      assert is_binary(opts[:doc])
    end
  end

  describe "restricted_key/0" do
    test "returns a keyword with :restricted" do
      assert [{:restricted, opts}] = Schema.restricted_key()
      assert opts[:type] == {:or, [:boolean, {:fun, 1}]}
      assert opts[:default] == false
      assert is_binary(opts[:doc])
    end
  end

  describe "access_predicates/0" do
    test "concatenates :visible and :restricted in that order" do
      result = Schema.access_predicates()
      assert Keyword.has_key?(result, :visible)
      assert Keyword.has_key?(result, :restricted)
      assert [{key1, _}, {key2, _}] = result
      assert {key1, key2} == {:visible, :restricted}
    end

    test "result is mergeable with another keyword (via ++)" do
      base = [name: [type: :atom, required: true]]
      merged = base ++ Schema.access_predicates()

      assert Keyword.keys(merged) == [:name, :visible, :restricted]
    end
  end
end
