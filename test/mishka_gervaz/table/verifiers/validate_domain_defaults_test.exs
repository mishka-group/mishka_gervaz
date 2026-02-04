defmodule MishkaGervaz.Verifiers.ValidateDomainDefaultsTest do
  @moduledoc """
  Tests for the ValidateDomainDefaults verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.DomainInfo

  describe "domain defaults validation" do
    test "valid domain config compiles successfully" do
      # Test.Domain has valid ui_adapter
      config = DomainInfo.domain_config(MishkaGervaz.Test.Domain)

      assert config.table.ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
      assert config.table.pagination.page_size == 20
    end

    test "valid ui_adapter is configured correctly" do
      ui_adapter = DomainInfo.default_ui_adapter(MishkaGervaz.Test.Domain)
      assert ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
    end

    test "valid pagination page_size is configured correctly" do
      pagination = DomainInfo.default_pagination(MishkaGervaz.Test.Domain)
      assert pagination.page_size == 20
    end

    test "invalid ui_adapter module emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.InvalidUIAdapterDomain#{unique_id} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        mishka_gervaz do
          table do
            ui_adapter NonExistent.UIAdapter.Module#{unique_id}
          end
        end

        resources do
          allow_unregistered? true
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "UI adapter module"
      assert output =~ "is not loaded"
      assert output =~ "Spark.Error.DslError"
    end

    test "invalid pubsub module emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.InvalidPubSubDomain#{unique_id} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        mishka_gervaz do
          table do
            realtime do
              pubsub NonExistent.PubSub.Module#{unique_id}
            end
          end
        end

        resources do
          allow_unregistered? true
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "PubSub module"
      assert output =~ "is not loaded"
      assert output =~ "Spark.Error.DslError"
    end

    test "domain without mishka_gervaz config compiles successfully" do
      unique_id = System.unique_integer([:positive])
      module_name = "MinimalDomain#{unique_id}"

      code = """
      defmodule MishkaGervaz.Test.#{module_name} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        resources do
          allow_unregistered? true
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

    test "domain with valid existing modules compiles successfully" do
      unique_id = System.unique_integer([:positive])
      module_name = "ValidModulesDomain#{unique_id}"

      code = """
      defmodule MishkaGervaz.Test.#{module_name} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        mishka_gervaz do
          table do
            ui_adapter MishkaGervaz.Table.UIAdapters.Tailwind

            pagination do
              page_size 50
              type :infinite
            end
          end
        end

        resources do
          allow_unregistered? true
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

    test "navigation menu_groups are configured correctly" do
      menu_groups = DomainInfo.menu_groups(MishkaGervaz.Test.Domain)

      assert length(menu_groups) == 2

      content_group = Enum.find(menu_groups, &(&1.name == :content))
      assert content_group.label == "Content"
      assert content_group.icon == "hero-document-text"

      users_group = Enum.find(menu_groups, &(&1.name == :users))
      assert users_group.label == "Users"
      assert users_group.icon == "hero-users"
    end
  end
end
