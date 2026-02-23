defmodule MishkaGervaz.Form.Verifiers.ValidateStepsTest do
  @moduledoc """
  Tests for the ValidateSteps verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    WizardForm,
    TabsForm
  }

  describe "positive: valid step configurations compile" do
    test "WizardForm compiles successfully" do
      config = FormInfo.config(WizardForm)
      assert config != nil
      assert length(FormInfo.steps(WizardForm)) == 3
    end

    test "TabsForm compiles successfully" do
      config = FormInfo.config(TabsForm)
      assert config != nil
      assert length(FormInfo.steps(TabsForm)) == 2
    end
  end

  describe "negative: standard mode with steps" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StandardWithSteps#{unique_id} do
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
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
            end

            groups do
              group :main do
                fields [:title]
              end
            end

            layout do
              mode :standard

              step :bad_step do
                groups [:main]
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

      assert output =~ "Steps cannot be defined when layout mode is `:standard`"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: wizard mode without steps" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.WizardNoSteps#{unique_id} do
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
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
            end

            layout do
              mode :wizard
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "requires at least one step"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: tabs mode without steps" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.TabsNoSteps#{unique_id} do
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
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
            end

            layout do
              mode :tabs
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "requires at least one step"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: step referencing non-existent group" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StepBadGroup#{unique_id} do
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
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
            end

            groups do
              group :existing do
                fields [:title]
              end
            end

            layout do
              mode :wizard

              step :first do
                groups [:non_existent_group]
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

      assert output =~ "references groups that don't exist"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: same group in two steps" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateStepGroup#{unique_id} do
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
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
            end

            groups do
              group :shared do
                fields [:title]
              end
            end

            layout do
              mode :wizard

              step :first do
                groups [:shared]
              end

              step :second do
                groups [:shared]
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

      assert output =~ "contains groups already in another step"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: two summary steps" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.TwoSummarySteps#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
          attribute :status, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
              field :status, :text
            end

            groups do
              group :g1 do
                fields [:title]
              end

              group :g2 do
                fields [:status]
              end
            end

            layout do
              mode :wizard

              step :step1 do
                groups [:g1]
                summary true
              end

              step :step2 do
                groups [:g2]
                summary true
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

      assert output =~ "At most one step can have `summary: true`"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: wizard mode with free navigation" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.WizardFreeNav#{unique_id} do
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
        end

        mishka_gervaz do
          form do
            fields do
              field :title, :text
            end

            groups do
              group :main do
                fields [:title]
              end
            end

            layout do
              mode :wizard
              navigation :free

              step :first do
                groups [:main]
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

      assert output =~ "Navigation `:free` is not valid with `:wizard` mode"
      assert output =~ "Spark.Error.DslError"
    end
  end
end
