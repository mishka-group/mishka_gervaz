defmodule MishkaGervaz.DSL.PresentationTest do
  @moduledoc """
  Tests for the presentation DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.Post
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  describe "presentation configuration" do
    test "presentation config is present" do
      config = ResourceInfo.table_config(Post)
      assert config.presentation != nil
    end

    test "template key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.template == MishkaGervaz.Table.Templates.Table
    end

    test "switchable_templates key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.switchable_templates == []
    end

    test "template_options key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)

      assert config.presentation.template_options == [
               striped: true,
               bordered: false,
               hoverable: true
             ]
    end

    test "features key is configured with specific list" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.features == [:sort, :filter, :select, :paginate]
    end

    test "ui_adapter key is configured" do
      config = ResourceInfo.table_config(Post)
      assert config.presentation.ui_adapter == MishkaGervaz.Table.UIAdapters.Tailwind
    end

    test "ui_adapter_opts key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.ui_adapter_opts == []
    end
  end

  describe "presentation theme nested section" do
    test "theme header_class key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.header_class == "bg-gray-100 text-gray-700"
    end

    test "theme row_class key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.row_class == "border-b"
    end

    test "theme border_class key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.border_class == "border-gray-200"
    end

    test "theme extra key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.theme.extra == %{compact: false}
    end
  end

  describe "presentation responsive nested section" do
    test "responsive hide_on_mobile key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.responsive.hide_on_mobile == [:content, :view_count]
    end

    test "responsive hide_on_tablet key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.responsive.hide_on_tablet == [:content]
    end

    test "responsive mobile_layout key is configured" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert config.presentation.responsive.mobile_layout == :cards
    end
  end

  describe "presentation defaults" do
    test "template defaults to Table in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Presentation.schema()
      template_config = Keyword.get(schema, :template)
      assert Keyword.get(template_config, :default) == MishkaGervaz.Table.Templates.Table
    end

    test "switchable_templates defaults to empty list in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Presentation.schema()
      switchable_config = Keyword.get(schema, :switchable_templates)
      assert Keyword.get(switchable_config, :default) == []
    end

    test "template_options defaults to empty list in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Presentation.schema()
      options_config = Keyword.get(schema, :template_options)
      assert Keyword.get(options_config, :default) == []
    end

    test "features defaults to :all in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Presentation.schema()
      features_config = Keyword.get(schema, :features)
      assert Keyword.get(features_config, :default) == :all
    end

    test "ui_adapter defaults to Tailwind in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Presentation.schema()
      adapter_config = Keyword.get(schema, :ui_adapter)
      assert Keyword.get(adapter_config, :default) == MishkaGervaz.Table.UIAdapters.Tailwind
    end

    test "ui_adapter_opts defaults to empty list in DSL schema" do
      schema = MishkaGervaz.Table.Dsl.Presentation.schema()
      opts_config = Keyword.get(schema, :ui_adapter_opts)
      assert Keyword.get(opts_config, :default) == []
    end
  end

  describe "features via TableInfo" do
    test "TableInfo.features/1 returns normalized feature list" do
      features = TableInfo.features(ComplexTestResource)
      assert is_list(features)
      assert :sort in features
      assert :filter in features
    end

    test "TableInfo.feature_enabled?/2 checks specific feature" do
      assert TableInfo.feature_enabled?(ComplexTestResource, :sort) == true
      assert TableInfo.feature_enabled?(ComplexTestResource, :filter) == true
      # Features not in the explicit list
      assert TableInfo.feature_enabled?(ComplexTestResource, :export) == false
    end

    test "default features returns :all when not set in DSL" do
      config = ResourceInfo.table_config(Post)
      # Default value is :all (enables all template features)
      assert config.presentation.features == :all
    end
  end

  describe "presentation has expected structure" do
    test "presentation is a map with all required keys" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.presentation)
      assert Map.has_key?(config.presentation, :template)
      assert Map.has_key?(config.presentation, :switchable_templates)
      assert Map.has_key?(config.presentation, :template_options)
      assert Map.has_key?(config.presentation, :features)
      assert Map.has_key?(config.presentation, :ui_adapter)
      assert Map.has_key?(config.presentation, :ui_adapter_opts)
      assert Map.has_key?(config.presentation, :theme)
      assert Map.has_key?(config.presentation, :responsive)
    end

    test "theme has expected structure" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.presentation.theme)
      assert Map.has_key?(config.presentation.theme, :header_class)
      assert Map.has_key?(config.presentation.theme, :row_class)
      assert Map.has_key?(config.presentation.theme, :border_class)
      assert Map.has_key?(config.presentation.theme, :extra)
    end

    test "responsive has expected structure" do
      config = ResourceInfo.table_config(ComplexTestResource)
      assert is_map(config.presentation.responsive)
      assert Map.has_key?(config.presentation.responsive, :hide_on_mobile)
      assert Map.has_key?(config.presentation.responsive, :hide_on_tablet)
      assert Map.has_key?(config.presentation.responsive, :mobile_layout)
    end
  end
end
