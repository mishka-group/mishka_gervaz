defmodule MishkaGervaz.Verifiers.ValidateFiltersTest do
  @moduledoc """
  Tests for the ValidateFilters verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.Post
  alias MishkaGervaz.Test.Resources.MinimalResource
  alias MishkaGervaz.ResourceInfo

  describe "filters validation" do
    test "valid filters with multiple filters compiles successfully" do
      # Post has 3 filters: search, status, user_id
      config = ResourceInfo.table_config(Post)

      filter_names = Enum.map(config.filters.list, & &1.name)
      assert :search in filter_names
      assert :status in filter_names
      assert :user_id in filter_names
    end

    test "filter options are configured correctly" do
      config = ResourceInfo.table_config(Post)

      search_filter = Enum.find(config.filters.list, &(&1.name == :search))
      assert search_filter.type == :text
      assert search_filter.fields == [:title, :content]

      status_filter = Enum.find(config.filters.list, &(&1.name == :status))
      assert status_filter.type == :select
    end

    test "no filters section compiles successfully" do
      # MinimalResource doesn't have filters section
      config = ResourceInfo.table_config(MinimalResource)

      assert config.filters == nil
    end

    test "empty filters section with filter_layout emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.EmptyFilters#{unique_id} do
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
              name :empty_filters
              route "/admin/empty-filters"
            end

            columns do
              column :name
            end

            filters do
              filter_layout mode: :inline
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "filters section requires at least one filter"
      assert output =~ "Spark.Error.DslError"
    end

    test "duplicate filter names emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateFilter#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
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
              name :duplicate_filter
              route "/admin/duplicate-filter"
            end

            columns do
              column :name
            end

            filters do
              filter :search, :text do
                fields [:name]
              end

              filter :search, :text do
                fields [:status]
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

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.Filter"
      assert output =~ "Filter: search"
      assert output =~ "Spark.Error.DslError"
    end

    test "multiple duplicate filter names reports all duplicates" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MultiDupFilter#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
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
              name :multi_dup_filter
              route "/admin/multi-dup-filter"
            end

            columns do
              column :name
            end

            filters do
              filter :search, :text do
                fields [:name]
              end

              filter :status, :select do
                options [[value: "active", label: "Active"]]
              end

              filter :search, :text do
                fields [:status]
              end

              filter :status, :select do
                options [[value: "inactive", label: "Inactive"]]
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

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.Filter"
      assert output =~ "MultiDupFilter#{unique_id}"
      assert output =~ "Filter: search" or output =~ "Filter: status"
      assert output =~ "Spark.Error.DslError"
    end

    test "filter with invalid depends_on reference emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.InvalidDependsOn#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
          attribute :category, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :invalid_depends_on
              route "/admin/invalid-depends-on"
            end

            columns do
              column :name
            end

            filters do
              filter :search, :text do
                fields [:name]
              end

              filter :category, :select do
                depends_on :non_existent_filter
                options [[value: "tech", label: "Tech"]]
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

      assert output =~ "Filters depend on non-existent filters"
      assert output =~ "category: :non_existent_filter"
      assert output =~ "Spark.Error.DslError"
    end

    test "filter with valid depends_on reference compiles successfully" do
      unique_id = System.unique_integer([:positive])
      module_name = "ValidDependsOn#{unique_id}"

      code = """
      defmodule MishkaGervaz.Test.#{module_name} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
          attribute :category, :string, public?: true
          attribute :subcategory, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :valid_depends_on
              route "/admin/valid-depends-on"
            end

            columns do
              column :name
            end

            filters do
              filter :category, :select do
                options [[value: "tech", label: "Tech"]]
              end

              filter :subcategory, :select do
                depends_on :category
                options [[value: "elixir", label: "Elixir"]]
              end
            end
          end
        end
      end
      """

      # Should compile without errors for THIS module
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      # Check that no error comes from our specific module
      refute output =~ "[MishkaGervaz.Test.#{module_name}]"
    end
  end
end
