defmodule MishkaGervaz.Verifiers.ValidateRowActionsTest do
  @moduledoc """
  Tests for the ValidateRowActions verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Test.Resources.Post
  alias MishkaGervaz.Test.Resources.ComplexTestResource
  alias MishkaGervaz.Test.Resources.MinimalResource
  alias MishkaGervaz.ResourceInfo

  describe "row_actions validation" do
    test "valid row_actions compiles successfully" do
      config = ResourceInfo.table_config(Post)

      action_names = Enum.map(config.row_actions.actions, & &1.name)
      assert :show in action_names
      assert :edit in action_names
      assert :publish in action_names
      assert :delete in action_names
    end

    test "row_actions with dropdown compiles successfully" do
      config = ResourceInfo.table_config(ComplexTestResource)

      # Check regular actions exist
      action_names = Enum.map(config.row_actions.actions, & &1.name)
      assert :view in action_names or :edit in action_names

      # Check dropdowns exist
      dropdowns = config.row_actions.dropdowns
      assert length(dropdowns) > 0

      dropdown = Enum.find(dropdowns, &(&1.name == :more_actions))
      assert dropdown != nil
      assert is_list(dropdown.items)
      assert length(dropdown.items) > 0
    end

    test "action types are configured correctly" do
      config = ResourceInfo.table_config(Post)

      show_action = Enum.find(config.row_actions.actions, &(&1.name == :show))
      assert show_action.type == :link
      assert is_function(show_action.path)

      publish_action = Enum.find(config.row_actions.actions, &(&1.name == :publish))
      assert publish_action.type == :event
      assert publish_action.event == "publish_post"

      delete_action = Enum.find(config.row_actions.actions, &(&1.name == :delete))
      assert delete_action.type == :destroy
    end

    test "no row_actions section compiles successfully" do
      config = ResourceInfo.table_config(MinimalResource)
      assert config.row_actions == nil
    end

    test "duplicate action names emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateRowAction#{unique_id} do
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
              name :dup_row_action
              route "/admin/dup-row-action"
            end

            columns do
              column :name
            end

            row_actions do
              action :edit do
                type :link
                path fn r -> "/edit/\#{r.id}" end
              end

              action :edit do
                type :link
                path fn r -> "/edit2/\#{r.id}" end
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

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.RowAction"
      assert output =~ "RowAction: edit"
      assert output =~ "Spark.Error.DslError"
    end

    test "duplicate dropdown names emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DuplicateDropdown#{unique_id} do
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
              name :dup_dropdown
              route "/admin/dup-dropdown"
            end

            columns do
              column :name
            end

            row_actions do
              dropdown :more do
                ui do
                  label "More"
                end

                action :duplicate do
                  type :event
                  event :dup
                end
              end

              dropdown :more do
                ui do
                  label "More Actions"
                end

                action :archive do
                  type :event
                  event :archive
                end
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

      assert output =~ "Got duplicate MishkaGervaz.Table.Entities.RowActionDropdown"
      assert output =~ "RowActionDropdown: more"
      assert output =~ "Spark.Error.DslError"
    end

    test "link action without path emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.LinkNoPath#{unique_id} do
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
              name :link_no_path
              route "/admin/link-no-path"
            end

            columns do
              column :name
            end

            row_actions do
              action :view do
                type :link
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

      assert output =~ "Action :view of type :link requires a :path option"
      assert output =~ "Spark.Error.DslError"
    end

    test "event action without event emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.EventNoEvent#{unique_id} do
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
              name :event_no_event
              route "/admin/event-no-event"
            end

            columns do
              column :name
            end

            row_actions do
              action :publish do
                type :event
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

      assert output =~ "Action :publish of type :event requires an :event option"
      assert output =~ "Spark.Error.DslError"
    end

    test "dropdown without ui label emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DropdownNoLabel#{unique_id} do
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
              name :dropdown_no_label
              route "/admin/dropdown-no-label"
            end

            columns do
              column :name
            end

            row_actions do
              dropdown :more do
                action :duplicate do
                  type :event
                  event :dup
                end
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

      assert output =~ "Dropdown :more requires a ui block with label"
      assert output =~ "Spark.Error.DslError"
    end

    test "action inside dropdown without required config emits DslError warning" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.DropdownActionInvalid#{unique_id} do
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
              name :dropdown_action_invalid
              route "/admin/dropdown-action-invalid"
            end

            columns do
              column :name
            end

            row_actions do
              dropdown :more do
                ui do
                  label "More"
                end

                action :view do
                  type :link
                end
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

      assert output =~ "In dropdown :more"
      assert output =~ "Action :view of type :link requires a :path option"
      assert output =~ "Spark.Error.DslError"
    end

    test "multiple validation errors are combined" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MultipleErrors#{unique_id} do
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
              name :multi_errors
              route "/admin/multi-errors"
            end

            columns do
              column :name
            end

            row_actions do
              action :view do
                type :link
              end

              action :publish do
                type :event
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

      assert output =~ "Action :view of type :link requires a :path option"
      assert output =~ "Action :publish of type :event requires an :event option"
      assert output =~ "Spark.Error.DslError"
    end
  end
end
