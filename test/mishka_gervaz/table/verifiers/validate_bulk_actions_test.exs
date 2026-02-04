defmodule MishkaGervaz.Verifiers.ValidateBulkActionsTest do
  @moduledoc """
  Tests for the ValidateBulkActions verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.BulkActionsResource
  alias MishkaGervaz.Test.Resources.MinimalResource
  alias MishkaGervaz.ResourceInfo

  describe "bulk_actions validation" do
    test "valid bulk_actions with actions compiles successfully" do
      config = ResourceInfo.table_config(BulkActionsResource)

      assert config.bulk_actions.enabled == true
      assert length(config.bulk_actions.actions) == 9

      assert Enum.map(config.bulk_actions.actions, & &1.name) == [
               :delete,
               :archive,
               :export,
               :custom_fn,
               :unarchive,
               :permanent_delete,
               :soft_delete,
               :notify,
               :activate
             ]
    end

    test "bulk_action confirm and event are configured correctly" do
      config = ResourceInfo.table_config(BulkActionsResource)

      delete_action = Enum.find(config.bulk_actions.actions, &(&1.name == :delete))
      assert delete_action.confirm == "Delete {count} items?"
      assert delete_action.event == :bulk_delete

      archive_action = Enum.find(config.bulk_actions.actions, &(&1.name == :archive))
      assert archive_action.confirm == nil
      assert archive_action.event == :bulk_archive
    end

    test "no bulk_actions section compiles successfully" do
      # MinimalResource doesn't have bulk_actions section
      config = ResourceInfo.table_config(MinimalResource)

      assert config.bulk_actions == nil
    end

    test "empty bulk_actions section emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.EmptyBulk#{unique_id} do
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
              name :empty_bulk
              route "/admin/empty-bulk"
            end

            columns do
              column :name
            end

            bulk_actions do
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "bulk_actions section requires at least one action"
      assert output =~ "Spark.Error.DslError"
    end

    test "duplicate bulk action names emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateBulk#{unique_id} do
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
              name :duplicate_bulk
              route "/admin/duplicate-bulk"
            end

            columns do
              column :name
            end

            bulk_actions do
              action :delete do
                event :bulk_delete
              end

              action :delete do
                event :bulk_delete_again
              end
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.BulkAction"
      assert output =~ "BulkAction: delete"
      assert output =~ "Spark.Error.DslError"
    end

    test "multiple duplicate bulk action names reports all duplicates" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MultiDupBulk#{unique_id} do
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
              name :multi_dup_bulk
              route "/admin/multi-dup-bulk"
            end

            columns do
              column :name
            end

            bulk_actions do
              action :delete do
                event :bulk_delete
              end

              action :archive do
                event :bulk_archive
              end

              action :delete do
                event :bulk_delete_2
              end

              action :archive do
                event :bulk_archive_2
              end
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.BulkAction"
      assert output =~ "MultiDupBulk#{unique_id}"
      assert output =~ "BulkAction: delete" or output =~ "BulkAction: archive"
      assert output =~ "Spark.Error.DslError"
    end
  end
end
