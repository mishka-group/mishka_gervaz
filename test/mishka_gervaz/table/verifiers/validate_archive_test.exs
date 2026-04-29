defmodule MishkaGervaz.Verifiers.ValidateArchiveTest do
  @moduledoc """
  Tests for archive section validation.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.ArchivableResource
  alias MishkaGervaz.ResourceInfo

  describe "archive section validation" do
    test "archive section with AshArchival.Resource compiles successfully" do
      # ArchivableResource has AshArchival.Resource extension
      config = ResourceInfo.table_config(ArchivableResource)

      assert config.source.archive != nil
      assert config.source.archive.enabled == true
      assert config.source.archive.restricted == true
    end

    test "archive actions are resolved correctly" do
      config = ResourceInfo.table_config(ArchivableResource)

      assert config.source.archive.actions.read == {:master_archived, :archived}
      assert config.source.archive.actions.get == {:master_get_archived, :get_archived}
      assert config.source.archive.actions.restore == {:master_unarchive, :unarchive}

      assert config.source.archive.actions.destroy ==
               {:master_permanent_destroy, :permanent_destroy}
    end

    test "archive section WITHOUT AshArchival.Resource emits DslError warning" do
      # Spark verifiers emit errors as warnings during compilation in test mode
      # We capture stderr to verify the error message is produced
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.InvalidArchive#{unique_id} do
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
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :invalid_archive_test
              route "/admin/invalid-archive"
            end

            source do
              archive do
                enabled true
                restricted true
                read_action :archived
              end
            end

            columns do
              column :title
            end
          end
        end
      end
      """

      # Capture IO to verify the DslError warning is emitted
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      # Verify the error message appears in the warning output
      assert output =~ "archive section requires AshArchival.Resource extension"
      assert output =~ "Spark.Error.DslError"
    end

    test "resource without archive section and without AshArchival compiles fine" do
      # This should not raise - no archive section defined
      config = ResourceInfo.table_config(MishkaGervaz.Test.Resources.Post)

      # Post doesn't have archive section, so it should be nil
      assert config.source.archive == nil
    end

    test "AshArchival without resource OR domain archive block raises DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.OrphanArchivalDomain#{unique_id} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        mishka_gervaz do
          table do
            actor_key :current_user
            master_check fn user -> user && user.role == :admin end

            actions do
              read {:master_read, :read}
              get {:master_get, :read}
              destroy {:master_destroy, :destroy}
            end
          end
        end

        resources do
          allow_unregistered? true
        end
      end

      defmodule MishkaGervaz.Test.OrphanArchival#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.OrphanArchivalDomain#{unique_id},
          extensions: [AshArchival.Resource, MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        archive do
          archive_related []
        end

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :orphan_archival_test
              route "/admin/orphan-archival"
            end

            columns do
              column :title
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "AshArchival.Resource is in the resource extensions"
      assert output =~ "Spark.Error.DslError"
    end

    test "AshArchival with domain archive block (and no resource block) compiles fine" do
      # ArchiveMergeInheritDomain has AshArchival.Resource and no resource-level
      # archive block. The Test.Domain provides archive defaults, so the
      # verifier must accept it. The runtime config must reflect inheritance.
      config = ResourceInfo.table_config(MishkaGervaz.Test.Resources.ArchiveMergeInheritDomain)

      assert config.source.archive.enabled == true
      assert config.source.archive.actions.read == {:master_archived, :archived}
    end
  end
end
