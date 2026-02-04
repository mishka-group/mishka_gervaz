defmodule MishkaGervaz.Verifiers.ValidateSourceTest do
  @moduledoc """
  Tests for the ValidateSource verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.Post
  alias MishkaGervaz.Test.Resources.ArchivableResource
  alias MishkaGervaz.Test.Resources.ComplexTestResource
  alias MishkaGervaz.ResourceInfo

  describe "archive section validation" do
    test "valid archive section with AshArchival compiles successfully" do
      config = ResourceInfo.table_config(ArchivableResource)
      assert config.source.archive.enabled == true
    end

    test "archive section without AshArchival emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.ArchiveNoExt#{unique_id} do
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
              name :archive_no_ext
              route "/admin/archive-no-ext"
            end

            source do
              archive do
                enabled true
              end
            end

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

      assert output =~ "archive section requires AshArchival.Resource extension"
      assert output =~ "Spark.Error.DslError"
    end

    test "no archive section without AshArchival compiles successfully" do
      config = ResourceInfo.table_config(Post)
      assert config.source.archive == nil
    end
  end

  describe "realtime prefix validation" do
    test "valid realtime with prefix compiles successfully" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.realtime.enabled == true
      assert config.realtime.prefix == "complex_posts"
    end

    test "realtime enabled without prefix emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.RealtimeNoPrefix#{unique_id} do
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
              name :realtime_no_prefix
              route "/admin/realtime-no-prefix"
            end

            columns do
              column :name
            end

            realtime do
              enabled true
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "realtime prefix is required when enabled"
      assert output =~ "Spark.Error.DslError"
    end

    test "realtime enabled with empty prefix emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.RealtimeEmptyPrefix#{unique_id} do
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
              name :realtime_empty_prefix
              route "/admin/realtime-empty-prefix"
            end

            columns do
              column :name
            end

            realtime do
              enabled true
              prefix ""
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "realtime prefix is required when enabled"
      assert output =~ "Spark.Error.DslError"
    end

    test "realtime disabled without prefix compiles successfully" do
      unique_id = System.unique_integer([:positive])
      module_name = "RealtimeDisabled#{unique_id}"

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
            identity do
              name :realtime_disabled
              route "/admin/realtime-disabled"
            end

            columns do
              column :name
            end

            realtime do
              enabled false
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      refute output =~ "[MishkaGervaz.Test.#{module_name}]"
    end

    test "no realtime section compiles successfully" do
      config = ResourceInfo.table_config(Post)
      # Post has realtime enabled: false in source
      assert config.realtime != nil
    end
  end
end
