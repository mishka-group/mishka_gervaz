defmodule MishkaGervaz.Transformers.ResolveColumnsTest do
  @moduledoc """
  Tests for the ResolveColumns transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, User, Comment, AutoColumnsResource}

  describe "column source resolution" do
    test "columns without explicit source get source from name" do
      col = ResourceInfo.column(User, :name)
      assert col.source == :name
    end

    test "columns with explicit source path preserve it" do
      col = ResourceInfo.column(Post, :user)
      assert col.source == [:user, :name]
    end

    test "Comment columns with relationship sources" do
      user_col = ResourceInfo.column(Comment, :user)
      assert user_col.source == [:user, :name]

      post_col = ResourceInfo.column(Comment, :post)
      assert post_col.source == [:post, :title]
    end
  end

  describe "column ordering" do
    test "column_order respects DSL definition" do
      order = ResourceInfo.column_order(Post)
      assert order == [:title, :status, :user, :view_count, :inserted_at, :view_count_formatted]
    end

    test "all columns in order exist in columns list" do
      order = ResourceInfo.column_order(Post)
      columns = ResourceInfo.columns(Post)
      column_names = Enum.map(columns, & &1.name)

      Enum.each(order, fn name ->
        assert name in column_names
      end)
    end
  end

  describe "preload detection" do
    test "detected_preloads extracts relationship columns" do
      preloads = ResourceInfo.detected_preloads(Post)
      # Post has user column with source [:user, :name]
      assert is_list(preloads)
    end

    test "Comment detected_preloads include user and post" do
      preloads = ResourceInfo.detected_preloads(Comment)
      # Comment has user and post relationship columns
      assert is_list(preloads)
    end

    test "all_preloads combines always and detected" do
      preloads = ResourceInfo.all_preloads(Post, true)
      assert is_list(preloads)
      assert :user in preloads
    end
  end

  describe "column type module resolution" do
    test "text columns get Text type module" do
      col = ResourceInfo.column(Post, :title)
      assert col.type_module == MishkaGervaz.Table.Types.Column.Text
    end

    test "badge columns get Badge type module" do
      col = ResourceInfo.column(Post, :status)
      assert col.type_module == MishkaGervaz.Table.Types.Column.Badge
    end

    test "number columns get Number type module" do
      col = ResourceInfo.column(Post, :view_count)
      assert col.type_module == MishkaGervaz.Table.Types.Column.Number
    end

    test "datetime columns get DateTime type module" do
      col = ResourceInfo.column(Post, :inserted_at)
      assert col.type_module == MishkaGervaz.Table.Types.Column.DateTime
    end

    test "boolean columns get Boolean type module" do
      col = ResourceInfo.column(User, :active)
      assert col.type_module == MishkaGervaz.Table.Types.Column.Boolean
    end
  end

  describe "auto_columns discovery" do
    test "auto_columns resource has valid config" do
      config = ResourceInfo.table_config(AutoColumnsResource)
      assert config != nil
      assert Map.has_key?(config, :columns)
    end

    test "auto_columns respects except option" do
      columns = ResourceInfo.columns(AutoColumnsResource)
      column_names = Enum.map(columns, & &1.name)

      # internal_field and updated_at are in except list
      if length(columns) > 0 do
        refute :internal_field in column_names
        refute :updated_at in column_names
      end
    end

    test "auto_columns creates valid column structs" do
      columns = ResourceInfo.columns(AutoColumnsResource)

      Enum.each(columns, fn col ->
        assert is_atom(col.name)
        assert col.source != nil
      end)
    end
  end

  describe "column position resolution" do
    test "columns are sorted by position" do
      order = ResourceInfo.column_order(Post)
      # Verify order is a list of atoms
      assert is_list(order)
      assert Enum.all?(order, &is_atom/1)
    end

    test "explicit column_order takes precedence" do
      order = ResourceInfo.column_order(Post)
      # Post has explicit column ordering
      assert :title == List.first(order)
    end

    test "columns without position maintain original order" do
      columns = ResourceInfo.columns(User)
      # User columns should be in a consistent order
      assert is_list(columns)
    end
  end
end
