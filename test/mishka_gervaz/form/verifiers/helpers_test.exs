defmodule MishkaGervaz.Form.Verifiers.HelpersTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Verifiers.Helpers` — the shared
  helpers imported by every verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Verifiers.Helpers
  alias MishkaGervaz.Form.Entities.Field

  describe "dsl_error/3" do
    test "wraps as {:error, %Spark.Error.DslError{}}" do
      assert {:error, %Spark.Error.DslError{} = err} =
               Helpers.dsl_error(SomeMod, [:a, :b], "boom")

      assert err.module == SomeMod
      assert err.path == [:a, :b]
      assert err.message == "boom"
    end
  end

  describe "entities_of/3" do
    test "returns [] when path has no entities" do
      assert Helpers.entities_of(%{}, [:nonexistent], Field) == []
    end

    test "filters to entities matching the struct type" do
      field = %Field{name: :title, type: :text}

      dsl_state = %{
        [:mishka_gervaz, :form, :fields] => %{
          entities: [field, %{name: :not_a_field}, "string"]
        }
      }

      result = Helpers.entities_of(dsl_state, [:mishka_gervaz, :form, :fields], Field)
      assert result == [field]
    end

    test "wraps non-list result safely" do
      assert Helpers.entities_of(%{}, [:any], Field) == []
    end
  end
end
