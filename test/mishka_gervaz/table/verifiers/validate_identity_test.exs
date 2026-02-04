defmodule MishkaGervaz.Verifiers.ValidateIdentityTest do
  @moduledoc """
  Tests for the ValidateIdentity verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.ValidIdentityTestResource
  alias MishkaGervaz.ResourceInfo

  describe "identity validation" do
    test "valid identity compiles successfully" do
      # Use pre-compiled resource to avoid protocol consolidation warning
      config = ResourceInfo.table_config(ValidIdentityTestResource)

      assert config.identity.name == :valid_table
      assert config.identity.route == "/admin/valid"
    end

    test "identity with all options configured correctly" do
      config = ResourceInfo.table_config(ValidIdentityTestResource)

      assert is_atom(config.identity.name)
      assert is_binary(config.identity.route)
    end

    test "missing identity name raises Spark.Error.DslError" do
      assert_raise Spark.Error.DslError, ~r/required :name option not found/, fn ->
        Code.compile_string("""
        defmodule MishkaGervaz.Test.InvalidNoName#{System.unique_integer([:positive])} do
          use Ash.Resource,
            domain: MishkaGervaz.Test.Domain,
            extensions: [MishkaGervaz.Resource],
            data_layer: Ash.DataLayer.Ets

          attributes do
            uuid_primary_key :id
            attribute :name, :string, allow_nil?: false, public?: true
          end

          actions do
            defaults [:read, :destroy, create: :*, update: :*]
            read :master_read
            read :tenant_read
          end

          mishka_gervaz do
            table do
              identity do
                route "/admin/test"
              end

              columns do
                column :name
              end
            end
          end
        end
        """)
      end
    end

    test "missing identity route raises Spark.Error.DslError" do
      assert_raise Spark.Error.DslError, ~r/required :route option not found/, fn ->
        Code.compile_string("""
        defmodule MishkaGervaz.Test.InvalidNoRoute#{System.unique_integer([:positive])} do
          use Ash.Resource,
            domain: MishkaGervaz.Test.Domain,
            extensions: [MishkaGervaz.Resource],
            data_layer: Ash.DataLayer.Ets

          attributes do
            uuid_primary_key :id
            attribute :name, :string, allow_nil?: false, public?: true
          end

          actions do
            defaults [:read, :destroy, create: :*, update: :*]
            read :master_read
            read :tenant_read
          end

          mishka_gervaz do
            table do
              identity do
                name :test_table
              end

              columns do
                column :name
              end
            end
          end
        end
        """)
      end
    end

    test "missing identity route without identity section emits DslError warning" do
      # When identity section is missing, the merge_defaults transformer
      # derives a name from the module, but route remains nil.
      # So verifier catches the missing route.
      unique_id = System.unique_integer([:positive])
      module_name = "NoIdentity#{unique_id}"

      code = """
      defmodule MishkaGervaz.Test.#{module_name} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            columns do
              column :name
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      # Verifier catches missing route (name is auto-derived from module)
      assert output =~ "identity.route is required"
      assert output =~ "Spark.Error.DslError"
    end

    test "empty identity section raises Spark.Error.DslError" do
      # Schema validates required options - route is validated first
      assert_raise Spark.Error.DslError, ~r/required :route option not found/, fn ->
        Code.compile_string("""
        defmodule MishkaGervaz.Test.EmptyIdentity#{System.unique_integer([:positive])} do
          use Ash.Resource,
            domain: MishkaGervaz.Test.Domain,
            extensions: [MishkaGervaz.Resource],
            data_layer: Ash.DataLayer.Ets

          attributes do
            uuid_primary_key :id
            attribute :name, :string, allow_nil?: false, public?: true
          end

          actions do
            defaults [:read, :destroy, create: :*, update: :*]
            read :master_read
            read :tenant_read
          end

          mishka_gervaz do
            table do
              identity do
              end

              columns do
                column :name
              end
            end
          end
        end
        """)
      end
    end
  end
end
