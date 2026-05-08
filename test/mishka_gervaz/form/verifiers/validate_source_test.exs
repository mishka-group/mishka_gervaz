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
end
