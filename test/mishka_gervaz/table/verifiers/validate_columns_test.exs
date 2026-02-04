defmodule MishkaGervaz.Verifiers.ValidateColumnsTest do
  @moduledoc """
  Tests for the ValidateColumns verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.Post
  alias MishkaGervaz.Test.Resources.MinimalResource
  alias MishkaGervaz.ResourceInfo

  describe "columns validation" do
    test "valid columns with unique names compiles successfully" do
      # Post has 5 unique columns: title, status, user, view_count, inserted_at
      config = ResourceInfo.table_config(Post)

      column_names = Enum.map(config.columns.list, & &1.name)
      assert :title in column_names
      assert :status in column_names
      assert :user in column_names
      assert :view_count in column_names
      assert :inserted_at in column_names
    end

    test "minimal resource with columns compiles successfully" do
      # MinimalResource has 2 columns: name, inserted_at
      config = ResourceInfo.table_config(MinimalResource)

      column_names = Enum.map(config.columns.list, & &1.name)
      assert length(column_names) == 2
      assert :name in column_names
      assert :inserted_at in column_names
    end

    test "column options are configured correctly" do
      config = ResourceInfo.table_config(Post)

      title_column = Enum.find(config.columns.list, &(&1.name == :title))
      assert title_column.sortable == true
      assert title_column.searchable == true

      status_column = Enum.find(config.columns.list, &(&1.name == :status))
      assert status_column.sortable == true
    end

    test "duplicate column names emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateColumn#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
          attribute :title, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :duplicate_column_test
              route "/admin/duplicate-column"
            end

            columns do
              column :name
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

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.Column"
      assert output =~ "Column: name"
      assert output =~ "Spark.Error.DslError"
    end

    test "multiple duplicate column names reports all duplicates" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MultiDupColumn#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
          attribute :title, :string, public?: true
          attribute :status, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :multi_dup_column_test
              route "/admin/multi-dup-column"
            end

            columns do
              column :name
              column :title
              column :name
              column :title
              column :status
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.Column"
      assert output =~ "MultiDupColumn#{unique_id}"
      assert output =~ "Column: name" or output =~ "Column: title"
      assert output =~ "Spark.Error.DslError"
    end

    test "same column name with different options still duplicates" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DupColumnDiffOpts#{unique_id} do
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
              name :dup_diff_opts_test
              route "/admin/dup-diff-opts"
            end

            columns do
              column :name do
                sortable true
              end

              column :name do
                sortable false
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

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.Column"
      assert output =~ "Column: name"
      assert output =~ "Spark.Error.DslError"
    end

    test "no columns defined emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.NoColumns#{unique_id} do
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
              name :no_columns_test
              route "/admin/no-columns"
            end

            columns do
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "No columns defined for the table"
      assert output =~ "Spark.Error.DslError"
    end

    test "auto_columns that results in no columns emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.AutoColumnsExcludeAll#{unique_id} do
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
              name :auto_columns_exclude_all_test
              route "/admin/auto-columns-exclude-all"
            end

            columns do
              auto_columns do
                except [:id, :name]
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

      assert output =~ "No columns defined for the table"
      assert output =~ "Spark.Error.DslError"
    end

    test "static column with render but no requires emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StaticNoRequires#{unique_id} do
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
              name :static_no_requires_test
              route "/admin/static-no-requires"
            end

            columns do
              column :custom_info do
                static true
                render fn _record -> "test" end
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

      assert output =~ "Static column" or output =~ "requires"
      assert output =~ "Spark.Error.DslError"
    end

    test "column not in resource attributes without static emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.NonExistentColumn#{unique_id} do
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
              name :non_existent_column_test
              route "/admin/non-existent-column"
            end

            columns do
              column :non_existent_field
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "not a resource field" or output =~ "non_existent_field"
      assert output =~ "Spark.Error.DslError"
    end

    test "static column with requires compiles successfully" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StaticWithRequires#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
          attribute :title, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :static_with_requires_test
              route "/admin/static-with-requires"
            end

            columns do
              column :custom_info do
                static true
                requires [:name, :title]
                render fn record -> record.name end
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

      # Check that no DslError was raised for THIS specific module
      refute output =~ "StaticWithRequires#{unique_id}]"
    end
  end
end
