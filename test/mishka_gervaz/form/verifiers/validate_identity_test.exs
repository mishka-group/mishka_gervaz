defmodule MishkaGervaz.Form.Verifiers.ValidateIdentityTest do
  @moduledoc """
  Tests for the `MishkaGervaz.Form.Verifiers.ValidateIdentity` verifier.

  The identity section's `name` is required. Both Spark's schema (via
  `required: true`) and this verifier guard the same constraint — the
  verifier is the final defense in case a transformer wipes the value.
  These tests assert the user-visible compile-time error regardless of
  which layer fires it.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost

  describe "positive: identity name is captured" do
    test "FormPost identity carries the configured name" do
      assert FormInfo.config(FormPost).identity[:name] == :form_post
    end
  end

  describe "negative: missing identity name" do
    test "compiling a form whose identity block omits :name fails" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MissingIdentity#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          form do
            identity do
              route "/admin/missing-#{unique_id}"
            end

            fields do
              field :title, :text
            end
          end
        end
      end
      """

      assert_raise Spark.Error.DslError, ~r/required :name option not found/, fn ->
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)
      end
    end
  end
end
