defmodule MishkaGervaz.Verifiers.ValidateSourceTest do
  @moduledoc """
  Tests for the ValidateSource verifier.
  """
  use ExUnit.Case, async: false

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
          read :master_get
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
          read :master_get
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
          read :master_get
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
          read :master_get
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

  describe "feature-aware required actions (get/destroy)" do
    defp compile_stderr(code) do
      ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.compile_string(code) end)
    end

    # A plain domain with NO gervaz default actions, so get/destroy are required
    # purely from the resource (isolates the feature-aware behavior from the
    # domain fallback that MishkaGervaz.Test.Domain provides).
    defp plain_domain(id), do: "MishkaGervaz.Test.PlainDomain#{id}"

    defp resource(id, name, source_actions, extra_table) do
      """
      defmodule #{plain_domain(id)} do
        use Ash.Domain, validate_config_inclusion?: false
      end

      defmodule MishkaGervaz.Test.#{name}#{id} do
        use Ash.Resource, domain: #{plain_domain(id)},
          extensions: [MishkaGervaz.Resource], data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :master_get
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :tbl_#{id}
              route "/admin/tbl-#{id}"
            end

            source do
              actions do
      #{source_actions}
              end
            end

            columns do
              column :name
            end
      #{extra_table}
          end
        end
      end
      """
    end

    test "a read-only table (no destructive/get feature) needs only read" do
      id = System.unique_integer([:positive])
      output = compile_stderr(resource(id, "ReadOnly", "read {:master_read, :tenant_read}", ""))

      refute output =~ "Missing required table source action"
    end

    test "a :destroy row action WITHOUT get/destroy fails at compile time, with reasons" do
      id = System.unique_integer([:positive])

      output =
        compile_stderr(
          resource(id, "NeedsDestroy", "read {:master_read, :tenant_read}", """
              row_actions do
                action :delete do
                  type :destroy
                end
              end
          """)
        )

      assert output =~ "Missing required table source action"
      assert output =~ ":get"
      assert output =~ ":destroy"
      assert output =~ "Spark.Error.DslError"
    end

    test "a :destroy row action WITH get + destroy declared compiles cleanly" do
      id = System.unique_integer([:positive])

      actions = """
      read {:master_read, :tenant_read}
                get {:master_read, :tenant_read}
                destroy {:destroy, :destroy}
      """

      output =
        compile_stderr(
          resource(id, "HasDestroy", actions, """
              row_actions do
                action :delete do
                  type :destroy
                end
              end
          """)
        )

      refute output =~ "Missing required table source action"
    end
  end

  describe "named actions the resource does not have" do
    defp compile_table(unique_id, extensions, actions, table) do
      code = """
      defmodule MishkaGervaz.Test.TableActions#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: #{extensions},
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          #{actions}
        end

        mishka_gervaz do
          table do
            identity do
              name :table_actions_#{unique_id}
              route "/admin/table-actions-#{unique_id}"
            end

            #{table}

            columns do
              column :name
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.compile_string(code) end)
    end

    @reads "defaults [:read, :destroy, create: :*]\n read :master_read"

    defp problems(output, unique_id) do
      header =
        "MishkaGervaz.Test.TableActions#{unique_id}'s table names actions the resource " <>
          "does not have:\n\n"

      case String.split(output, header, parts: 2) do
        [_before, rest] ->
          rest
          |> String.split("\n")
          |> Enum.take_while(&String.starts_with?(&1, "  * "))
          |> Enum.map(&String.replace_prefix(&1, "  * ", ""))

        [_no_error] ->
          []
      end
    end

    test "an inherited get the resource does not have names the domain it came from" do
      unique_id = System.unique_integer([:positive])

      assert unique_id
             |> compile_table("[MishkaGervaz.Resource]", @reads, "")
             |> problems(unique_id) == [
               "get {:master_get, :read}, inherited from MishkaGervaz.Test.Domain: " <>
                 "there is no read action named :master_get"
             ]
    end

    test "is reported as a compile warning, which --warnings-as-errors turns into a failed build" do
      unique_id = System.unique_integer([:positive])

      {_output, diagnostics} =
        Code.with_diagnostics(fn ->
          compile_table(unique_id, "[MishkaGervaz.Resource]", @reads, "")
        end)

      assert Enum.any?(diagnostics, fn diagnostic ->
               diagnostic.severity == :warning and
                 diagnostic.message =~ "table names actions the resource does not have"
             end)
    end

    test "a get set on the resource names the resource, though the domain names the same one" do
      unique_id = System.unique_integer([:positive])
      table = "source do\n actions do\n get {:master_get, :read}\n end\n end"

      assert unique_id
             |> compile_table("[MishkaGervaz.Resource]", @reads, table)
             |> problems(unique_id) == [
               "get {:master_get, :read}, set on the resource: " <>
                 "there is no read action named :master_get"
             ]
    end

    test "a destroy no row or bulk action uses is not checked" do
      unique_id = System.unique_integer([:positive])
      actions = @reads <> "\n read :master_get"

      assert unique_id
             |> compile_table("[MishkaGervaz.Resource]", actions, "")
             |> problems(unique_id) == []
    end

    test "a destroy a row action uses is checked" do
      unique_id = System.unique_integer([:positive])
      actions = @reads <> "\n read :master_get"

      row_actions = """
      row_actions do
        action :delete do
          type :destroy
        end
      end
      """

      assert unique_id
             |> compile_table("[MishkaGervaz.Resource]", actions, row_actions)
             |> problems(unique_id) == [
               "destroy {:master_destroy, :destroy}, inherited from MishkaGervaz.Test.Domain: " <>
                 "there is no destroy action named :master_destroy"
             ]
    end

    test "an archive action the resource does not have is named" do
      unique_id = System.unique_integer([:positive])

      actions = """
      defaults [:read, :destroy, create: :*, update: :*]
      read :master_read
      read :master_get
      read :master_archived
      read :archived
      read :master_get_archived
      read :get_archived
      update :unarchive, accept: []
      destroy :master_permanent_destroy
      destroy :permanent_destroy
      """

      table = "source do\n archive do\n restore_action {:master_restore, :unarchive}\n end\n end"

      assert unique_id
             |> compile_table("[AshArchival.Resource, MishkaGervaz.Resource]", actions, table)
             |> problems(unique_id) == [
               "archive restore {:master_restore, :unarchive}, set on the resource: " <>
                 "there is no update action named :master_restore"
             ]
    end
  end
end
