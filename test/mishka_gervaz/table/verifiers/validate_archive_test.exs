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
  end
end
