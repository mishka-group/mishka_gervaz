defmodule MishkaGervaz.Table.SortFieldTest do
  @moduledoc """
  Comprehensive tests for the sort_field DSL option.

  Tests cover:
  - Column entity defaults and opt_schema
  - Compile-time verifier validation
  - Runtime config transformer output
  - State sort_field_map construction
  - State get_features union across switchable templates
  - DataLoader apply_sort with sort_field groups
  - Template get_sort_info with sort_field_map
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.State.Helpers, as: StateHelpers
  alias MishkaGervaz.Table.Entities.Column
  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.Post

  # ============================================================================
  # Column Entity: sort_field defaults and opt_schema
  # ============================================================================

  describe "Column entity sort_field defaults" do
    test "sort_field defaults to empty list in opt_schema" do
      schema = Column.opt_schema()
      sort_field_config = Keyword.get(schema, :sort_field)
      assert Keyword.get(sort_field_config, :default) == []
    end

    test "sort_field type is {:list, :atom} in opt_schema" do
      schema = Column.opt_schema()
      sort_field_config = Keyword.get(schema, :sort_field)
      assert Keyword.get(sort_field_config, :type) == {:list, :atom}
    end

    test "sort_field has documentation" do
      schema = Column.opt_schema()
      sort_field_config = Keyword.get(schema, :sort_field)
      assert Keyword.get(sort_field_config, :doc) != nil
    end

    test "Column struct has sort_field field with default []" do
      column = %Column{}
      assert column.sort_field == []
    end
  end

  # ============================================================================
  # Verifier: compile-time validation
  # ============================================================================

  describe "verifier: static + sortable without sort_field" do
    test "emits DslError when static + sortable but no sort_field" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StaticSortableNoSortField#{unique_id} do
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
              name :sort_field_test_#{unique_id}
              route "/admin/sort-field-test-#{unique_id}"
            end

            columns do
              column :display_label do
                static true
                sortable true
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

      assert output =~ "must specify `sort_field`"
      assert output =~ "Spark.Error.DslError"
    end

    test "emits DslError mentioning the column name" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.SortFieldMissing#{unique_id} do
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
              name :sf_missing_#{unique_id}
              route "/admin/sf-missing-#{unique_id}"
            end

            columns do
              column :computed_col do
                static true
                sortable true
                requires [:name]
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

      assert output =~ "computed_col"
      assert output =~ "sort_field"
    end
  end

  describe "verifier: invalid sort_field values" do
    test "emits DslError when sort_field references non-existent field" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.InvalidSortField#{unique_id} do
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
              name :invalid_sf_#{unique_id}
              route "/admin/invalid-sf-#{unique_id}"
            end

            columns do
              column :display do
                static true
                sortable true
                sort_field [:nonexistent_field]
                requires [:name]
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

      assert output =~ "invalid sort_field"
      assert output =~ "nonexistent_field"
      assert output =~ "Spark.Error.DslError"
    end

    test "emits DslError listing all invalid fields" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MultiInvalidSortField#{unique_id} do
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
              name :multi_invalid_sf_#{unique_id}
              route "/admin/multi-invalid-sf-#{unique_id}"
            end

            columns do
              column :display do
                static true
                sortable true
                sort_field [:bad_field1, :bad_field2]
                requires [:name]
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

      assert output =~ "bad_field1"
      assert output =~ "bad_field2"
    end
  end

  describe "verifier: valid sort_field configurations" do
    test "static + sortable + valid sort_field compiles without error" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.ValidSortField#{unique_id} do
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
              name :valid_sf_#{unique_id}
              route "/admin/valid-sf-#{unique_id}"
            end

            columns do
              column :display_name do
                static true
                sortable true
                sort_field [:name]
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
      refute output =~ "ValidSortField#{unique_id}]"
    end

    test "static + sortable + multiple valid sort_fields compiles without error" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.MultiSortField#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :first_name, :string, allow_nil?: false, public?: true
          attribute :last_name, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :multi_sf_#{unique_id}
              route "/admin/multi-sf-#{unique_id}"
            end

            columns do
              column :full_name do
                static true
                sortable true
                sort_field [:last_name, :first_name]
                requires [:first_name, :last_name]
                render fn record -> "\#{record.first_name} \#{record.last_name}" end
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
      refute output =~ "MultiSortField#{unique_id}]"
    end

    test "non-static sortable column without sort_field compiles fine" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.NonStaticSortable#{unique_id} do
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
              name :non_static_sortable_#{unique_id}
              route "/admin/non-static-sortable-#{unique_id}"
            end

            columns do
              column :name do
                sortable true
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
      refute output =~ "NonStaticSortable#{unique_id}]"
    end

    test "static + not sortable without sort_field compiles fine" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.StaticNotSortable#{unique_id} do
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
              name :static_not_sortable_#{unique_id}
              route "/admin/static-not-sortable-#{unique_id}"
            end

            columns do
              column :label do
                static true
                requires [:name]
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
      refute output =~ "StaticNotSortable#{unique_id}]"
    end
  end

  # ============================================================================
  # Runtime config: sort_field preserved in column_to_map
  # ============================================================================

  describe "runtime config: sort_field in compiled config" do
    test "sort_field is present in column config map" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.SortFieldConfig#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false, public?: true
          attribute :score, :integer, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
          read :master_read
          read :tenant_read
        end

        mishka_gervaz do
          table do
            identity do
              name :sf_config_#{unique_id}
              route "/admin/sf-config-#{unique_id}"
            end

            columns do
              column :display do
                static true
                sortable true
                sort_field [:name, :score]
                requires [:name, :score]
                render fn record -> record.name end
              end

              column :name do
                sortable true
              end
            end
          end
        end
      end
      """

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(code)
      end)

      module = Module.concat(MishkaGervaz.Test, :"SortFieldConfig#{unique_id}")
      config = ResourceInfo.table_config(module)

      display_col = Enum.find(config.columns.list, &(&1.name == :display))
      assert display_col.sort_field == [:name, :score]

      name_col = Enum.find(config.columns.list, &(&1.name == :name))
      assert name_col.sort_field == []
    end
  end

  # ============================================================================
  # State: sort_field_map construction
  # ============================================================================

  describe "StateHelpers.build_sort_field_map/1" do
    test "builds map from sortable columns with sort_field" do
      columns = [
        %{name: :display, sortable: true, sort_field: [:name, :score]},
        %{name: :title, sortable: true, sort_field: []},
        %{name: :icon, sortable: false, sort_field: []}
      ]

      result = StateHelpers.build_sort_field_map(columns)

      assert result == %{
               display: [:name, :score],
               title: [:title]
             }
    end

    test "falls back to column name when sort_field is empty" do
      columns = [
        %{name: :title, sortable: true, sort_field: []},
        %{name: :status, sortable: true, sort_field: nil}
      ]

      result = StateHelpers.build_sort_field_map(columns)

      assert result[:title] == [:title]
      assert result[:status] == [:status]
    end

    test "excludes non-sortable columns" do
      columns = [
        %{name: :title, sortable: true, sort_field: [:title]},
        %{name: :icon, sortable: false, sort_field: []}
      ]

      result = StateHelpers.build_sort_field_map(columns)

      assert Map.has_key?(result, :title)
      refute Map.has_key?(result, :icon)
    end

    test "returns empty map when no sortable columns" do
      columns = [
        %{name: :icon, sortable: false, sort_field: []},
        %{name: :label, sortable: false, sort_field: []}
      ]

      result = StateHelpers.build_sort_field_map(columns)
      assert result == %{}
    end

    test "handles single sort_field entry" do
      columns = [
        %{name: :computed, sortable: true, sort_field: [:score]}
      ]

      result = StateHelpers.build_sort_field_map(columns)
      assert result == %{computed: [:score]}
    end
  end

  describe "State init includes sort_field_map" do
    test "sort_field_map is present in static state" do
      state = State.init("test-id", Post, nil)

      assert is_map(state.static.sort_field_map)
    end

    test "sort_field_map contains sortable columns" do
      state = State.init("test-id", Post, nil)

      # Post has :title, :status, :view_count, :inserted_at as sortable
      sortable_names = state.static.sortable_columns

      Enum.each(sortable_names, fn name ->
        assert Map.has_key?(state.static.sort_field_map, name),
               "Expected #{name} in sort_field_map"
      end)
    end

    test "non-static sortable columns default to [column_name]" do
      state = State.init("test-id", Post, nil)

      # :title is a non-static sortable column in Post, should default to [:title]
      assert state.static.sort_field_map[:title] == [:title]
    end
  end

  # ============================================================================
  # State: get_features union across switchable templates
  # ============================================================================

  describe "StateHelpers.get_features/2 with switchable templates" do
    test "returns union of features from all switchable templates" do
      # Create a mock config with switchable templates
      template_a = MishkaGervaz.Table.Templates.Table

      config = %{
        presentation: %{
          features: nil,
          switchable_templates: [template_a]
        }
      }

      features = StateHelpers.get_features(config, template_a)

      # Table template has :sort in its features
      assert :sort in features
    end

    test "returns explicit features when configured" do
      config = %{
        presentation: %{
          features: [:sort, :filter],
          switchable_templates: []
        }
      }

      features = StateHelpers.get_features(config, MishkaGervaz.Table.Templates.Table)

      assert features == [:sort, :filter]
    end

    test "includes current template in features union" do
      template = MishkaGervaz.Table.Templates.Table

      config = %{
        presentation: %{
          features: nil,
          switchable_templates: []
        }
      }

      features = StateHelpers.get_features(config, template)

      # Even without switchable templates, current template features are included
      assert :sort in features
    end
  end

  # ============================================================================
  # DataLoader: apply_sort with sort_field groups (unit testing the logic)
  # ============================================================================

  describe "sort_field group logic: adding new sort" do
    test "adds sort_field group when column not yet sorted" do
      sort_field_map = %{display: [:name, :score], title: [:title]}
      current_sorts = [{:title, :asc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :display)

      assert new_sorts == [{:name, :asc}, {:score, :asc}, {:title, :asc}]
    end

    test "adds single field for column without explicit sort_field" do
      sort_field_map = %{title: [:title]}
      current_sorts = []

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :title)

      assert new_sorts == [{:title, :asc}]
    end

    test "falls back to column name when not in sort_field_map" do
      sort_field_map = %{}
      current_sorts = []

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :unknown)

      assert new_sorts == [{:unknown, :asc}]
    end
  end

  describe "sort_field group logic: cycling existing first sort" do
    test "toggles sort_field group from asc to desc when first" do
      sort_field_map = %{display: [:name, :score]}
      current_sorts = [{:name, :asc}, {:score, :asc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :display)

      assert new_sorts == [{:name, :desc}, {:score, :desc}]
    end

    test "removes sort_field group when cycling from desc at first position" do
      sort_field_map = %{display: [:name, :score]}
      current_sorts = [{:name, :desc}, {:score, :desc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :display)

      assert new_sorts == []
    end

    test "removes group and preserves other sorts when cycling from desc" do
      sort_field_map = %{display: [:name, :score], title: [:title]}
      current_sorts = [{:name, :desc}, {:score, :desc}, {:title, :asc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :display)

      assert new_sorts == [{:title, :asc}]
    end
  end

  describe "sort_field group logic: promoting non-first sort" do
    test "promotes sort_field group to first and toggles direction" do
      sort_field_map = %{display: [:name, :score], title: [:title]}
      current_sorts = [{:title, :asc}, {:name, :asc}, {:score, :asc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :display)

      # :display was asc, promoted to first position and toggled to desc
      assert new_sorts == [{:name, :desc}, {:score, :desc}, {:title, :asc}]
    end

    test "promotes single-field column to first and toggles" do
      sort_field_map = %{status: [:status], title: [:title]}
      current_sorts = [{:title, :asc}, {:status, :desc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :status)

      assert new_sorts == [{:status, :asc}, {:title, :asc}]
    end
  end

  describe "sort_field group logic: backward compatibility" do
    test "single-field sort without sort_field works like before: add asc" do
      sort_field_map = %{name: [:name]}
      current_sorts = []

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :name)

      assert new_sorts == [{:name, :asc}]
    end

    test "single-field sort: asc to desc cycle" do
      sort_field_map = %{name: [:name]}
      current_sorts = [{:name, :asc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :name)

      assert new_sorts == [{:name, :desc}]
    end

    test "single-field sort: desc to remove cycle" do
      sort_field_map = %{name: [:name]}
      current_sorts = [{:name, :desc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :name)

      assert new_sorts == []
    end

    test "single-field sort: promote from non-first" do
      sort_field_map = %{name: [:name], score: [:score]}
      current_sorts = [{:name, :asc}, {:score, :asc}]

      new_sorts = simulate_apply_sort_logic(sort_field_map, current_sorts, :score)

      assert new_sorts == [{:score, :desc}, {:name, :asc}]
    end
  end

  # ============================================================================
  # Template: get_sort_info with sort_field_map
  # ============================================================================

  describe "sort indicator resolution with sort_field_map" do
    test "resolves sort info using primary field from sort_field_map" do
      sort_field_map = %{display: [:name, :score]}
      sort_fields = [{:name, :asc}]

      {direction, position} = get_sort_info(:display, sort_fields, sort_field_map)

      assert direction == :asc
      assert position == nil
    end

    test "resolves sort info with multiple sorts and position" do
      sort_field_map = %{display: [:name, :score], title: [:title]}
      sort_fields = [{:name, :asc}, {:title, :desc}]

      {direction, position} = get_sort_info(:display, sort_fields, sort_field_map)

      assert direction == :asc
      assert position == 1
    end

    test "returns nil when column not currently sorted" do
      sort_field_map = %{display: [:name, :score]}
      sort_fields = [{:title, :asc}]

      {direction, position} = get_sort_info(:display, sort_fields, sort_field_map)

      assert direction == nil
      assert position == nil
    end

    test "falls back to column name when not in sort_field_map" do
      sort_field_map = %{}
      sort_fields = [{:title, :desc}]

      {direction, position} = get_sort_info(:title, sort_fields, sort_field_map)

      assert direction == :desc
      assert position == nil
    end

    test "position is correct for second sort field" do
      sort_field_map = %{title: [:title], status: [:status]}
      sort_fields = [{:title, :asc}, {:status, :desc}]

      {direction, position} = get_sort_info(:status, sort_fields, sort_field_map)

      assert direction == :desc
      assert position == 2
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  # Simulates the apply_sort logic from DataLoader without needing a socket
  defp simulate_apply_sort_logic(sort_field_map, current_sorts, column) do
    db_fields = Map.get(sort_field_map, column, [column])
    primary = List.first(db_fields) || column
    existing_index = Enum.find_index(current_sorts, fn {f, _} -> f == primary end)

    case existing_index do
      nil ->
        Enum.map(db_fields, &{&1, :asc}) ++ current_sorts

      0 ->
        {_, current_order} = Enum.at(current_sorts, 0)

        case current_order do
          :asc -> toggle_sort_group(current_sorts, db_fields, :desc)
          :desc -> remove_sort_group(current_sorts, db_fields)
        end

      _index ->
        {_, current_order} = Enum.find(current_sorts, fn {f, _} -> f == primary end)
        new_order = if current_order == :asc, do: :desc, else: :asc
        rest = remove_sort_group(current_sorts, db_fields)
        Enum.map(db_fields, &{&1, new_order}) ++ rest
    end
  end

  defp toggle_sort_group(sorts, db_fields, new_order) do
    Enum.map(sorts, fn {f, ord} ->
      if f in db_fields, do: {f, new_order}, else: {f, ord}
    end)
  end

  defp remove_sort_group(sorts, db_fields) do
    Enum.reject(sorts, fn {f, _} -> f in db_fields end)
  end

  # Mirrors the get_sort_info logic from the Table template
  defp get_sort_info(column, sort_fields, sort_field_map) do
    primary =
      case Map.get(sort_field_map, column) do
        [first | _] -> first
        _ -> column
      end

    case Enum.find_index(sort_fields, fn {f, _} -> f == primary end) do
      nil ->
        {nil, nil}

      index ->
        {_field, order} = Enum.at(sort_fields, index)
        position = if length(sort_fields) > 1, do: index + 1, else: nil
        {order, position}
    end
  end
end
