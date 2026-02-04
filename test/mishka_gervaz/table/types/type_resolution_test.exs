defmodule MishkaGervaz.Table.Types.TypeResolutionTest do
  @moduledoc """
  Tests for type resolution logic.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Column, as: ColumnType
  alias MishkaGervaz.Table.Types.Filter, as: FilterType
  alias MishkaGervaz.Table.Types.Action, as: ActionType
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, User, CustomTypesResource}

  describe "Column type resolution" do
    test "user-specified type via DSL is respected" do
      # Post has :inserted_at with explicit ui type :datetime
      col = ResourceInfo.column(Post, :inserted_at)
      assert col.ui.type == :datetime
      assert col.type_module == ColumnType.DateTime
    end

    test "user-specified :badge type is respected" do
      col = ResourceInfo.column(Post, :status)
      assert col.ui.type == :badge
      assert col.type_module == ColumnType.Badge
    end

    test "user-specified :number type is respected" do
      col = ResourceInfo.column(Post, :view_count)
      assert col.ui.type == :number
      assert col.type_module == ColumnType.Number
    end

    test "user-specified :boolean type is respected" do
      col = ResourceInfo.column(User, :active)
      assert col.ui.type == :boolean
      assert col.type_module == ColumnType.Boolean
    end

    test "column without explicit type gets auto-detected from Ash attribute" do
      # User.name has no explicit type, should auto-detect from Ash.Type.String
      col = ResourceInfo.column(User, :name)
      # name has no ui.type set (or defaults to :text)
      assert col.type_module == ColumnType.Text
    end

    test "column without explicit type but with Ash Boolean type gets Boolean module" do
      # If we have a column without ui type but the Ash attribute is boolean
      # it should be auto-detected. Let's verify with User.active via State.init
      state = State.init("test-id", User, nil)
      active_col = Enum.find(state.static.columns, &(&1.name == :active))
      assert active_col.type_module == ColumnType.Boolean
    end

    test "State.init respects DSL-specified types" do
      state = State.init("test-id", Post, nil)

      # Verify that types set in DSL are not overwritten
      status_col = Enum.find(state.static.columns, &(&1.name == :status))
      assert status_col.type_module == ColumnType.Badge

      view_count_col = Enum.find(state.static.columns, &(&1.name == :view_count))
      assert view_count_col.type_module == ColumnType.Number

      inserted_at_col = Enum.find(state.static.columns, &(&1.name == :inserted_at))
      assert inserted_at_col.type_module == ColumnType.DateTime
    end

    test "State.init auto-detects types for columns without explicit type" do
      state = State.init("test-id", User, nil)

      # name column has no explicit type, should be auto-detected
      name_col = Enum.find(state.static.columns, &(&1.name == :name))
      assert name_col.type_module == ColumnType.Text

      # email column has no explicit type, should be auto-detected
      email_col = Enum.find(state.static.columns, &(&1.name == :email))
      assert email_col.type_module == ColumnType.Text
    end
  end

  describe "Column type resolution function" do
    test "resolve_type returns existing type_module if set" do
      # If type_module is already set, it should be returned as-is
      column = %{type_module: ColumnType.Badge, name: :status, ui: nil}
      attributes = %{}

      result = ColumnType.resolve_type(column, attributes)
      assert result == ColumnType.Badge
    end

    test "resolve_type checks ui.type when type_module is nil" do
      column = %{type_module: nil, name: :status, ui: %{type: :number}}
      attributes = %{}

      result = ColumnType.resolve_type(column, attributes)
      assert result == ColumnType.Number
    end

    test "resolve_type falls back to Ash type inference when no explicit type" do
      column = %{type_module: nil, name: :active, ui: nil}
      attributes = %{active: %{type: Ash.Type.Boolean}}

      result = ColumnType.resolve_type(column, attributes)
      assert result == ColumnType.Boolean
    end

    test "resolve_type returns Text for unknown Ash types" do
      column = %{type_module: nil, name: :custom, ui: nil}
      attributes = %{custom: %{type: SomeUnknownType}}

      result = ColumnType.resolve_type(column, attributes)
      assert result == ColumnType.Text
    end

    test "resolve_type handles struct ui correctly" do
      ui_struct = %MishkaGervaz.Table.Entities.Column.Ui{type: :datetime}
      column = %{type_module: nil, name: :created, ui: ui_struct}
      attributes = %{}

      result = ColumnType.resolve_type(column, attributes)
      assert result == ColumnType.DateTime
    end
  end

  describe "Ash type inference" do
    test "infers Boolean from Ash.Type.Boolean" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.Boolean}) == ColumnType.Boolean
    end

    test "infers Number from Ash.Type.Integer" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.Integer}) == ColumnType.Number
    end

    test "infers Number from Ash.Type.Float" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.Float}) == ColumnType.Number
    end

    test "infers Number from Ash.Type.Decimal" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.Decimal}) == ColumnType.Number
    end

    test "infers Date from Ash.Type.Date" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.Date}) == ColumnType.Date
    end

    test "infers DateTime from Ash.Type.DateTime" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.DateTime}) == ColumnType.DateTime
    end

    test "infers DateTime from Ash.Type.UtcDatetime" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.UtcDatetime}) == ColumnType.DateTime
    end

    test "infers DateTime from Ash.Type.UtcDatetimeUsec" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.UtcDatetimeUsec}) ==
               ColumnType.DateTime
    end

    test "infers UUID from Ash.Type.UUID" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.UUID}) == ColumnType.UUID
    end

    test "infers UUID from Ash.Type.UUIDv7" do
      assert ColumnType.infer_from_ash_type(%{type: Ash.Type.UUIDv7}) == ColumnType.UUID
    end

    test "infers Array from {:array, type}" do
      assert ColumnType.infer_from_ash_type(%{type: {:array, Ash.Type.String}}) ==
               ColumnType.Array
    end

    test "defaults to Text for nil attribute" do
      assert ColumnType.infer_from_ash_type(nil) == ColumnType.Text
    end

    test "defaults to Text for unknown types" do
      assert ColumnType.infer_from_ash_type(%{type: SomeCustomType}) == ColumnType.Text
    end
  end

  describe "Filter type resolution" do
    test "user-specified filter type is respected" do
      filter = ResourceInfo.filter(Post, :status)
      assert filter.type == :select
      assert filter.type_module == FilterType.Select
    end

    test "text filter gets correct type module" do
      filter = ResourceInfo.filter(Post, :search)
      assert filter.type == :text
      assert filter.type_module == FilterType.Text
    end

    test "relation filter gets correct type module" do
      filter = ResourceInfo.filter(Post, :user_id)
      assert filter.type == :relation
      assert filter.type_module == FilterType.Relation
    end

    test "boolean filter gets correct type module" do
      filter = ResourceInfo.filter(User, :active)
      assert filter.type == :boolean
      assert filter.type_module == FilterType.Boolean
    end

    test "State.init respects DSL-specified filter types" do
      state = State.init("test-id", Post, nil)

      search_filter = Enum.find(state.static.filters, &(&1.name == :search))
      assert search_filter.type_module == FilterType.Text

      status_filter = Enum.find(state.static.filters, &(&1.name == :status))
      assert status_filter.type_module == FilterType.Select
    end
  end

  describe "Filter type resolution function" do
    test "resolve_type returns correct module for built-in types" do
      assert FilterType.resolve_type(%{type: :text}) == FilterType.Text
      assert FilterType.resolve_type(%{type: :select}) == FilterType.Select
      assert FilterType.resolve_type(%{type: :boolean}) == FilterType.Boolean
      assert FilterType.resolve_type(%{type: :number}) == FilterType.Number
      assert FilterType.resolve_type(%{type: :date}) == FilterType.Date
      assert FilterType.resolve_type(%{type: :date_range}) == FilterType.DateRange
      assert FilterType.resolve_type(%{type: :relation}) == FilterType.Relation
    end

    test "resolve_type defaults to Text when no type specified" do
      assert FilterType.resolve_type(%{}) == FilterType.Text
    end
  end

  describe "Action type resolution" do
    test "user-specified action type is respected" do
      actions = ResourceInfo.row_actions(Post)
      show_action = Enum.find(actions, &(&1.name == :show))
      assert show_action.type == :link
      assert show_action.type_module == ActionType.Link
    end

    test "destroy action gets correct type module" do
      actions = ResourceInfo.row_actions(Post)
      delete_action = Enum.find(actions, &(&1.name == :delete))
      assert delete_action.type == :destroy
      assert delete_action.type_module == ActionType.Destroy
    end

    test "event action gets correct type module" do
      actions = ResourceInfo.row_actions(Post)
      publish_action = Enum.find(actions, &(&1.name == :publish))
      assert publish_action.type == :event
      assert publish_action.type_module == ActionType.Event
    end
  end

  describe "Action type resolution function" do
    test "resolve_type returns correct module for built-in types" do
      assert ActionType.resolve_type(%{type: :link}) == ActionType.Link
      assert ActionType.resolve_type(%{type: :event}) == ActionType.Event
      assert ActionType.resolve_type(%{type: :destroy}) == ActionType.Destroy
      assert ActionType.resolve_type(%{type: :row_click}) == ActionType.RowClick
    end

    test "resolve_type defaults to Event when no type specified" do
      assert ActionType.resolve_type(%{}) == ActionType.Event
    end
  end

  describe "Custom type modules" do
    test "get_or_passthrough returns module as-is for custom types" do
      # Custom modules that are not in the built-in registry should be passed through
      custom_module = MyApp.CustomColumnType

      result = ColumnType.get_or_passthrough(custom_module)
      assert result == custom_module
    end

    test "get_or_passthrough returns built-in module for known types" do
      assert ColumnType.get_or_passthrough(:text) == ColumnType.Text
      assert ColumnType.get_or_passthrough(:badge) == ColumnType.Badge
      assert ColumnType.get_or_passthrough(:boolean) == ColumnType.Boolean
    end

    test "filter get_or_passthrough works for custom types" do
      custom_module = MyApp.CustomFilterType
      result = FilterType.get_or_passthrough(custom_module)
      assert result == custom_module
    end

    test "action get_or_passthrough works for custom types" do
      custom_module = MyApp.CustomActionType
      result = ActionType.get_or_passthrough(custom_module)
      assert result == custom_module
    end
  end

  describe "Type registry functions" do
    test "Column builtin_types returns all built-in column types" do
      types = ColumnType.builtin_types()
      assert :text in types
      assert :boolean in types
      assert :badge in types
      assert :number in types
      assert :date in types
      assert :datetime in types
      assert :uuid in types
      assert :array in types
      assert :link in types
    end

    test "Column builtin? returns true for built-in types" do
      assert ColumnType.builtin?(:text)
      assert ColumnType.builtin?(:boolean)
      assert ColumnType.builtin?(:badge)
      refute ColumnType.builtin?(:custom_type)
    end

    test "Filter builtin_types returns all built-in filter types" do
      types = FilterType.builtin_types()
      assert :text in types
      assert :select in types
      assert :boolean in types
      assert :number in types
      assert :date in types
      assert :date_range in types
      assert :relation in types
    end

    test "Action builtin_types returns all built-in action types" do
      types = ActionType.builtin_types()
      assert :link in types
      assert :event in types
      assert :destroy in types
      assert :row_click in types
    end

    test "Column default returns Text type" do
      assert ColumnType.default() == ColumnType.Text
    end

    test "Filter default returns Text type" do
      assert FilterType.default() == FilterType.Text
    end

    test "Action default returns Event type" do
      assert ActionType.default() == ActionType.Event
    end
  end

  describe "Custom type modules in DSL" do
    test "custom column type module is respected in DSL" do
      col = ResourceInfo.column(CustomTypesResource, :custom_field)
      assert col.type_module == MishkaGervaz.Test.CustomColumnType
    end

    test "custom column type module is preserved in State.init" do
      state = State.init("test-id", CustomTypesResource, nil)
      custom_col = Enum.find(state.static.columns, &(&1.name == :custom_field))

      assert custom_col.type_module == MishkaGervaz.Test.CustomColumnType
    end

    test "built-in type still works alongside custom types" do
      state = State.init("test-id", CustomTypesResource, nil)

      status_col = Enum.find(state.static.columns, &(&1.name == :status))
      assert status_col.type_module == ColumnType.Badge

      inserted_at_col = Enum.find(state.static.columns, &(&1.name == :inserted_at))
      assert inserted_at_col.type_module == ColumnType.DateTime
    end

    test "auto-detection works for columns without explicit type" do
      state = State.init("test-id", CustomTypesResource, nil)
      name_col = Enum.find(state.static.columns, &(&1.name == :name))

      # name has no explicit type, should be auto-detected as Text
      assert name_col.type_module == ColumnType.Text
    end

    test "custom filter type module is respected in DSL" do
      filter = ResourceInfo.filter(CustomTypesResource, :custom_filter)
      assert filter.type_module == MishkaGervaz.Test.CustomFilterType
    end

    test "custom filter type module is preserved in State.init" do
      state = State.init("test-id", CustomTypesResource, nil)
      custom_filter = Enum.find(state.static.filters, &(&1.name == :custom_filter))

      assert custom_filter.type_module == MishkaGervaz.Test.CustomFilterType
    end

    test "built-in filter type still works alongside custom types" do
      state = State.init("test-id", CustomTypesResource, nil)
      status_filter = Enum.find(state.static.filters, &(&1.name == :status))

      assert status_filter.type_module == FilterType.Select
    end

    test "custom action type module is respected in DSL" do
      actions = ResourceInfo.row_actions(CustomTypesResource)
      custom_action = Enum.find(actions, &(&1.name == :custom_action))

      assert custom_action.type_module == MishkaGervaz.Test.CustomActionType
    end

    test "built-in action type still works alongside custom types" do
      actions = ResourceInfo.row_actions(CustomTypesResource)
      show_action = Enum.find(actions, &(&1.name == :show))

      assert show_action.type_module == ActionType.Link
    end
  end
end
