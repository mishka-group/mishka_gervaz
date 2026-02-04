defmodule MishkaGervaz.DSL.ColumnsTest do
  @moduledoc """
  Tests for the columns DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo

  alias MishkaGervaz.Test.Resources.{
    Post,
    User,
    Comment,
    AutoColumnsResource,
    ComplexTestResource
  }

  describe "column definitions" do
    test "returns all columns for a resource" do
      columns = ResourceInfo.columns(Post)
      assert is_list(columns)
      assert length(columns) > 0
    end

    test "each column is a Column struct" do
      columns = ResourceInfo.columns(Post)

      Enum.each(columns, fn column ->
        assert is_struct(column, MishkaGervaz.Table.Entities.Column)
      end)
    end

    test "column names are atoms" do
      columns = ResourceInfo.columns(Post)
      column_names = Enum.map(columns, & &1.name)
      assert :title in column_names
      assert :status in column_names
      assert :user in column_names
      assert :view_count in column_names
      assert :inserted_at in column_names
    end

    test "retrieves specific column by name" do
      column = ResourceInfo.column(Post, :title)
      assert column.name == :title
    end

    test "returns nil for non-existent column" do
      column = ResourceInfo.column(Post, :non_existent)
      assert column == nil
    end
  end

  describe "column properties" do
    test "sortable attribute is correctly set" do
      title_col = ResourceInfo.column(Post, :title)
      assert title_col.sortable == true

      user_col = ResourceInfo.column(Post, :user)
      assert user_col.sortable == false
    end

    test "searchable attribute is correctly set" do
      title_col = ResourceInfo.column(Post, :title)
      assert title_col.searchable == true

      status_col = ResourceInfo.column(Post, :status)
      assert status_col.searchable != true
    end

    test "source attribute for relationship columns" do
      user_col = ResourceInfo.column(Post, :user)
      assert user_col.source == [:user, :name]
    end

    test "ui configuration is captured" do
      title_col = ResourceInfo.column(Post, :title)
      assert title_col.ui.label == "Title"
      assert title_col.ui.class == "font-semibold"
    end

    test "ui type is correctly set" do
      status_col = ResourceInfo.column(Post, :status)
      assert status_col.ui.type == :badge

      view_count_col = ResourceInfo.column(Post, :view_count)
      assert view_count_col.ui.type == :number

      inserted_at_col = ResourceInfo.column(Post, :inserted_at)
      assert inserted_at_col.ui.type == :datetime
    end
  end

  describe "column_order" do
    test "returns ordered column names" do
      column_order = ResourceInfo.column_order(Post)

      assert column_order == [
               :title,
               :status,
               :user,
               :view_count,
               :inserted_at,
               :view_count_formatted
             ]
    end

    test "column_order matches defined columns" do
      column_order = ResourceInfo.column_order(Post)
      columns = ResourceInfo.columns(Post)
      column_names = Enum.map(columns, & &1.name)

      # All columns in column_order should exist
      Enum.each(column_order, fn name ->
        assert name in column_names,
               "column_order contains #{name} but it's not in columns"
      end)
    end
  end

  describe "default_sort" do
    test "default_sort is correctly set" do
      config = ResourceInfo.table_config(Post)
      assert config.columns.default_sort == {:inserted_at, :desc}
    end
  end

  describe "format option" do
    test "format function (1-arity) is correctly set" do
      col = ResourceInfo.column(Post, :inserted_at)
      assert is_function(col.format, 1)
    end

    test "format function (3-arity) is correctly set" do
      col = ResourceInfo.column(Post, :view_count_formatted)
      assert is_function(col.format, 3)
    end

    test "format 1-arity transforms value" do
      col = ResourceInfo.column(Post, :inserted_at)
      datetime = ~U[2026-01-01 21:32:44Z]
      result = col.format.(datetime)
      assert result == "2026/01/01 21:32"
    end

    test "format 3-arity transforms value with state and record" do
      col = ResourceInfo.column(Post, :view_count_formatted)
      result = col.format.(nil, %{id: 1}, 42)
      assert result == "42 views"
    end

    test "column without format has nil format field" do
      col = ResourceInfo.column(Post, :title)
      assert Map.get(col, :format) == nil
    end

    test "format is preserved when building state columns" do
      state = MishkaGervaz.Table.Web.State.init("test", Post, nil)
      col = Enum.find(state.static.columns, &(&1.name == :inserted_at))
      assert is_function(Map.get(col, :format), 1)
    end

    test "format is applied via apply_format helper with 1-arity" do
      format_fn = fn value -> "formatted: #{value}" end
      result = apply_test_format(format_fn, nil, nil, "test")
      assert result == "formatted: test"
    end

    test "format is applied via apply_format helper with 3-arity" do
      format_fn = fn state, record, value -> "#{state}-#{record.id}-#{value}" end
      result = apply_test_format(format_fn, "state", %{id: 1}, "val")
      assert result == "state-1-val"
    end

    test "apply_format returns value unchanged when format is nil" do
      result = apply_test_format(nil, nil, nil, "original")
      assert result == "original"
    end
  end

  defp apply_test_format(nil, _state, _record, value), do: value

  defp apply_test_format(format, _state, _record, value) when is_function(format, 1),
    do: format.(value)

  defp apply_test_format(format, state, record, value) when is_function(format, 3),
    do: format.(state, record, value)

  defp apply_test_format(_format, _state, _record, value), do: value

  describe "User resource columns" do
    test "has expected columns" do
      columns = ResourceInfo.columns(User)
      column_names = Enum.map(columns, & &1.name)
      assert :name in column_names
      assert :email in column_names
      assert :role in column_names
      assert :active in column_names
      assert :inserted_at in column_names
    end

    test "name column is searchable" do
      col = ResourceInfo.column(User, :name)
      assert col.searchable == true
    end

    test "email column is searchable" do
      col = ResourceInfo.column(User, :email)
      assert col.searchable == true
    end

    test "active column has boolean type" do
      col = ResourceInfo.column(User, :active)
      assert col.ui.type == :boolean
    end
  end

  describe "Comment resource columns" do
    test "has relationship columns with source paths" do
      user_col = ResourceInfo.column(Comment, :user)
      assert user_col.source == [:user, :name]

      post_col = ResourceInfo.column(Comment, :post)
      assert post_col.source == [:post, :title]
    end
  end

  describe "auto_columns feature" do
    test "auto_columns resource has config" do
      config = ResourceInfo.table_config(AutoColumnsResource)
      assert config != nil
      assert Map.has_key?(config, :columns)
    end

    test "auto_columns respects except list" do
      columns = ResourceInfo.columns(AutoColumnsResource)
      column_names = Enum.map(columns, & &1.name)

      # If columns exist, check that excluded fields are not present
      if length(columns) > 0 do
        refute :internal_field in column_names
        refute :updated_at in column_names
      end
    end

    test "auto_columns creates column structs when present" do
      columns = ResourceInfo.columns(AutoColumnsResource)

      Enum.each(columns, fn column ->
        assert is_struct(column, MishkaGervaz.Table.Entities.Column)
      end)
    end

    test "auto_columns override passes format option" do
      col = ResourceInfo.column(AutoColumnsResource, :inserted_at)
      assert is_function(col.format, 1)
      datetime = ~U[2026-01-01 21:32:44Z]
      result = col.format.(datetime)
      assert result == "01/01/2026"
    end
  end

  describe "all Column entity keys (ComplexTestResource)" do
    test "name key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.name == :title
    end

    test "source key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.source == :title
    end

    test "sortable key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.sortable == true
    end

    test "searchable key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.searchable == true
    end

    test "filterable key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.filterable == false
    end

    test "visible key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.visible == true
    end

    test "position key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.position == :first
    end

    test "export key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.export == true
    end

    test "export_as key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.export_as == :post_title
    end

    test "default key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.default == "Untitled"
    end

    test "separator key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.separator == " - "
    end

    test "label key at column level is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.label == "Post Title"
    end
  end

  describe "all Column.Ui keys (ComplexTestResource)" do
    test "ui label key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.label == "Title"
    end

    test "ui type key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.type == :text
    end

    test "ui width key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.width == "250px"
    end

    test "ui min_width key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.min_width == "150px"
    end

    test "ui max_width key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.max_width == "400px"
    end

    test "ui align key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.align == :left
    end

    test "ui class key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.class == "font-semibold"
    end

    test "ui header_class key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.header_class == "text-primary"
    end

    test "ui extra key is configured" do
      col = ResourceInfo.column(ComplexTestResource, :title)
      assert col.ui.extra == %{truncate: 50}
    end
  end

  describe "Column entity defaults" do
    test "sortable defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      sortable_config = Keyword.get(schema, :sortable)
      assert Keyword.get(sortable_config, :default) == false
    end

    test "searchable defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      searchable_config = Keyword.get(schema, :searchable)
      assert Keyword.get(searchable_config, :default) == false
    end

    test "filterable defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      filterable_config = Keyword.get(schema, :filterable)
      assert Keyword.get(filterable_config, :default) == false
    end

    test "visible defaults to true in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      visible_config = Keyword.get(schema, :visible)
      assert Keyword.get(visible_config, :default) == true
    end

    test "export defaults to true in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      export_config = Keyword.get(schema, :export)
      assert Keyword.get(export_config, :default) == true
    end

    test "separator defaults to space in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      separator_config = Keyword.get(schema, :separator)
      assert Keyword.get(separator_config, :default) == " "
    end

    test "static defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      static_config = Keyword.get(schema, :static)
      assert Keyword.get(static_config, :default) == false
    end

    test "requires defaults to empty list in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.opt_schema()
      requires_config = Keyword.get(schema, :requires)
      assert Keyword.get(requires_config, :default) == []
    end
  end

  describe "Column.Ui entity defaults" do
    test "type defaults to :text in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.Ui.opt_schema()
      type_config = Keyword.get(schema, :type)
      assert Keyword.get(type_config, :default) == :text
    end

    test "align defaults to :left in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.Ui.opt_schema()
      align_config = Keyword.get(schema, :align)
      assert Keyword.get(align_config, :default) == :left
    end

    test "extra defaults to empty map in opt_schema" do
      schema = MishkaGervaz.Table.Entities.Column.Ui.opt_schema()
      extra_config = Keyword.get(schema, :extra)
      assert Keyword.get(extra_config, :default) == %{}
    end
  end

  describe "columns via TableInfo" do
    test "TableInfo.columns/1 returns all columns" do
      columns = TableInfo.columns(ComplexTestResource)
      assert is_list(columns)
      column_names = Enum.map(columns, & &1.name)
      assert :title in column_names
      assert :status in column_names
    end

    test "TableInfo.column/2 returns specific column" do
      col = TableInfo.column(ComplexTestResource, :title)
      assert col.name == :title
    end

    test "TableInfo.column_order/1 returns ordered names" do
      order = TableInfo.column_order(ComplexTestResource)
      assert is_list(order)
      assert :title in order
    end
  end
end
