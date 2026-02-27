defmodule MishkaGervaz.Form.Verifiers.ValidateGroupsTest do
  @moduledoc """
  Tests for the ValidateGroups verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost

  describe "positive: valid groups compile" do
    test "FormPost groups compile with correct field references" do
      groups = FormInfo.groups(FormPost)
      assert length(groups) == 2

      general = Enum.find(groups, &(&1.name == :general))
      assert general.fields == [:title, :content, :status, :language]

      settings = Enum.find(groups, &(&1.name == :settings))
      assert settings.fields == [:priority, :featured, :metadata, :user_id]
    end
  end

  describe "negative: group referencing non-existent field" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.GroupBadField#{unique_id} do
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
                fields [:title, :non_existent_field]
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

      assert output =~ "references fields that don't exist"
      assert output =~ "non_existent_field"
      assert output =~ "Spark.Error.DslError"
    end
  end

  describe "negative: field in two groups" do
    test "emits DslError" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateGroupField#{unique_id} do
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
              group :group_a do
                fields [:title, :status]
              end

              group :group_b do
                fields [:title]
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

      assert output =~ "contains fields already in another group"
      assert output =~ "title"
      assert output =~ "Spark.Error.DslError"
    end
  end
end
