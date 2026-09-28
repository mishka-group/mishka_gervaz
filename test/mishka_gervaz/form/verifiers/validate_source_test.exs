defmodule MishkaGervaz.Form.Verifiers.ValidateSourceTest do
  @moduledoc """
  Tests for `MishkaGervaz.Form.Verifiers.ValidateSource`.

  Covers the verifier's reachable responsibility:

  - **Required actions** — `create`, `update`, `read` must come from either
    the resource or the domain. Both nil = compile error.

  The `master_check` branch in the verifier is currently unreachable
  because `MishkaGervaz.Form.Transformers.MergeDefaults.merge_master_check_default/1`
  always persists a fallback MFA. The positive cases below assert that
  fallback is wired correctly.

  The verifier guards with `form_used?/1`, so a form without fields is a
  no-op and skips validation.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.NoMasterCheckForm

  describe "positive: domain inheritance" do
    test "actions inherited from domain compile without resource declaration" do
      config = FormInfo.config(NoMasterCheckForm)
      assert config.source.actions.create == {:master_create, :create}
      assert config.source.actions.update == {:master_update, :update}
      assert config.source.actions.read == {:master_get, :read}
    end

    test "default master_check fallback fires when resource & domain both omit it" do
      config = FormInfo.config(NoMasterCheckForm)
      assert is_function(config.source.master_check, 1)
    end
  end

  describe "negative: required actions missing on resource and domain" do
    test "emits DslError listing every missing action" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.NoFormDefaultsDomain#{unique_id} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        resources do
          allow_unregistered? true
        end
      end

      defmodule MishkaGervaz.Test.MissingActions#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.NoFormDefaultsDomain#{unique_id},
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
          table do
            identity do
              name :missing_actions_t#{unique_id}
              route "/admin/missing-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            identity do
              name :missing_actions_f#{unique_id}
              route "/admin/missing-#{unique_id}"
            end

            fields do
              field :title, :text
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "Missing required form source action"
      assert output =~ ":create"
      assert output =~ ":update"
      assert output =~ ":read"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "edge: empty fields skip validation" do
    test "form with no fields compiles even with no actions configured" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.NoFieldsDomain#{unique_id} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        resources do
          allow_unregistered? true
        end
      end

      defmodule MishkaGervaz.Test.NoFieldsForm#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.NoFieldsDomain#{unique_id},
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
          table do
            identity do
              name :no_fields_t#{unique_id}
              route "/admin/no-fields-#{unique_id}"
            end

            columns do
              column :title
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(code)
      end)

      module = Module.concat(MishkaGervaz.Test, :"NoFieldsForm#{unique_id}")
      assert function_exported?(module, :spark_dsl_config, 0)
    end
  end

  describe "negative: named actions the resource does not have" do
    defp compile_form(unique_id, form_source, actions) do
      code = """
      defmodule MishkaGervaz.Test.NamedActionsDomain#{unique_id} do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain],
          validate_config_inclusion?: false

        mishka_gervaz do
          form do
            actions do
              create {:master_create, :create}
              update {:master_update, :update}
              read {:master_get, :read}
            end
          end
        end

        resources do
          allow_unregistered? true
        end
      end

      defmodule MishkaGervaz.Test.NamedActions#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.NamedActionsDomain#{unique_id},
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, public?: true
        end

        actions do
          #{actions}
        end

        mishka_gervaz do
          form do
            identity do
              name :named_actions_f#{unique_id}
              route "/admin/named-actions-#{unique_id}"
            end

            source do
              #{form_source}
            end

            fields do
              field :title, :text
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.compile_string(code) end)
    end

    @create_only "defaults [:read, create: :*]\n  create :master_create, accept: :*"

    defp problems(output, unique_id) do
      header =
        "MishkaGervaz.Test.NamedActions#{unique_id}'s form names actions the resource " <>
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

    test "names each missing action and the domain it came from" do
      unique_id = System.unique_integer([:positive])
      domain = "MishkaGervaz.Test.NamedActionsDomain#{unique_id}"

      assert unique_id |> compile_form("", @create_only) |> problems(unique_id) == [
               "update {:master_update, :update}, inherited from #{domain}: " <>
                 "there is no update action named :master_update",
               "update {:master_update, :update}, inherited from #{domain}: " <>
                 "there is no update action named :update",
               "read {:master_get, :read}, inherited from #{domain}: " <>
                 "there is no read action named :master_get"
             ]
    end

    test "says an action set on the resource is set there" do
      unique_id = System.unique_integer([:positive])
      source = "actions do\n update :rename\n read :read\n end"

      assert unique_id |> compile_form(source, @create_only) |> problems(unique_id) == [
               "update :rename, set on the resource: there is no update action named :rename"
             ]
    end

    test "is reported as a compile warning, which --warnings-as-errors turns into a failed build" do
      unique_id = System.unique_integer([:positive])

      {_output, diagnostics} =
        Code.with_diagnostics(fn -> compile_form(unique_id, "", @create_only) end)

      assert Enum.any?(diagnostics, fn diagnostic ->
               diagnostic.severity == :warning and
                 diagnostic.message =~ "form names actions the resource does not have"
             end)
    end

    test "says an action set on the resource is set there, though the domain names the same one" do
      unique_id = System.unique_integer([:positive])
      source = "actions do\n update {:master_update, :update}\n read :read\n end"

      assert unique_id |> compile_form(source, @create_only) |> problems(unique_id) == [
               "update {:master_update, :update}, set on the resource: " <>
                 "there is no update action named :master_update",
               "update {:master_update, :update}, set on the resource: " <>
                 "there is no update action named :update"
             ]
    end

    test "says when the named action is of another kind" do
      unique_id = System.unique_integer([:positive])
      source = "actions do\n update :master_create\n read :read\n end"

      assert unique_id |> compile_form(source, @create_only) |> problems(unique_id) == [
               "update :master_create, set on the resource: " <>
                 ":master_create is a create action, not an update action"
             ]
    end

    test "a mode closed with access :update, false needs no update or read action" do
      unique_id = System.unique_integer([:positive])

      assert unique_id
             |> compile_form("access :update, false", @create_only)
             |> problems(unique_id) ==
               []

      module = Module.concat(MishkaGervaz.Test, :"NamedActions#{unique_id}")
      assert function_exported?(module, :spark_dsl_config, 0)
    end

    test "closing the update mode still checks the create action" do
      unique_id = System.unique_integer([:positive])
      domain = "MishkaGervaz.Test.NamedActionsDomain#{unique_id}"

      output = compile_form(unique_id, "access :update, false", "defaults [:read, create: :*]")

      assert problems(output, unique_id) == [
               "create {:master_create, :create}, inherited from #{domain}: " <>
                 "there is no create action named :master_create"
             ]
    end
  end
end
