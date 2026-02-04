defmodule MishkaGervaz.DSL.BulkActionsTest do
  @moduledoc """
  Tests for the bulk_actions DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.{Post, User, BulkActionsResource, ComplexTestResource}

  describe "bulk action definitions" do
    test "returns all bulk actions for a resource" do
      actions = ResourceInfo.bulk_actions(Post)
      assert is_list(actions)
    end

    test "each action is a BulkAction struct" do
      actions = ResourceInfo.bulk_actions(Post)

      Enum.each(actions, fn action ->
        assert is_struct(action, MishkaGervaz.Table.Entities.BulkAction)
      end)
    end
  end

  describe "delete bulk action" do
    test "Post has delete bulk action" do
      actions = ResourceInfo.bulk_actions(Post)
      delete_action = Enum.find(actions, &(&1.name == :delete))
      assert delete_action != nil
    end

    test "delete bulk action has confirm message" do
      actions = ResourceInfo.bulk_actions(Post)
      delete_action = Enum.find(actions, &(&1.name == :delete))
      assert delete_action.confirm == "Delete selected posts?"
    end

    test "User delete bulk action" do
      actions = ResourceInfo.bulk_actions(User)
      delete_action = Enum.find(actions, &(&1.name == :delete))
      assert delete_action != nil
      assert delete_action.confirm == "Delete selected users?"
    end
  end

  describe "bulk action counts" do
    test "Post has correct number of bulk actions" do
      actions = ResourceInfo.bulk_actions(Post)
      assert length(actions) == 1
    end

    test "User has correct number of bulk actions" do
      actions = ResourceInfo.bulk_actions(User)
      assert length(actions) == 1
    end
  end

  describe "bulk action handler types" do
    test "parent handler type" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      delete_action = Enum.find(actions, &(&1.name == :delete))
      assert delete_action.handler == :parent
    end

    test "atom handler type (single Ash action)" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      archive_action = Enum.find(actions, &(&1.name == :archive))
      assert archive_action.handler == :bulk_archive_action
    end

    test "tuple handler type (master/tenant Ash actions)" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      export_action = Enum.find(actions, &(&1.name == :export))
      assert export_action.handler == {:master_bulk_export, :tenant_bulk_export}
    end

    test "function handler type" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      custom_action = Enum.find(actions, &(&1.name == :custom_fn))
      assert is_function(custom_action.handler, 2)
    end
  end

  describe "bulk action handler defaults" do
    test "handler defaults to :parent when not specified" do
      actions = ResourceInfo.bulk_actions(Post)
      delete_action = Enum.find(actions, &(&1.name == :delete))
      assert delete_action.handler == :parent
    end
  end

  describe "bulk action type option" do
    test "type :event sets handler to {:type, :event}" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :notify))
      assert action.type == :event
      assert action.handler == {:type, :event}
      assert action.event == :bulk_notify
    end

    test "type :destroy sets handler to {:type, :destroy}" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :soft_delete))
      assert action.type == :destroy
      assert action.handler == {:type, :destroy}
    end

    test "type :update sets handler to {:type, :update}" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :activate))
      assert action.type == :update
      assert action.handler == {:type, :update}
      assert action.action == {:master_activate, :activate}
    end

    test "type :unarchive sets handler to {:type, :unarchive}" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :unarchive))
      assert action.type == :unarchive
      assert action.handler == {:type, :unarchive}
    end

    test "type :permanent_destroy sets handler to {:type, :permanent_destroy}" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :permanent_delete))
      assert action.type == :permanent_destroy
      assert action.handler == {:type, :permanent_destroy}
    end

    test "type-based action has confirm message" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :unarchive))
      assert action.confirm == "Restore {count} items?"
    end

    test "type-based action has visible setting" do
      actions = ResourceInfo.bulk_actions(BulkActionsResource)
      action = Enum.find(actions, &(&1.name == :unarchive))
      assert action.visible == :archived
    end

    test "builtin_action_types returns valid types" do
      types = MishkaGervaz.Table.Entities.BulkAction.builtin_action_types()
      assert :event in types
      assert :destroy in types
      assert :update in types
      assert :unarchive in types
      assert :permanent_destroy in types
    end
  end

  defp get_ui(action) do
    case action.ui do
      [ui | _] -> ui
      ui when is_struct(ui) -> ui
      _ -> nil
    end
  end

  describe "all BulkAction entity keys (ComplexTestResource)" do
    test "name key is configured" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      assert action.name == :bulk_delete
    end

    test "confirm key is configured with string" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      assert action.confirm == "Delete {count} selected posts?"
    end

    test "confirm key is configured with boolean true" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_archive))
      assert action.confirm == true
    end

    test "confirm key is configured with boolean false" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_publish))
      assert action.confirm == false
    end

    test "event key is configured" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      assert action.event == :bulk_delete
    end

    test "payload key is configured as function" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      assert is_function(action.payload, 1)
    end

    test "payload function returns correct map" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      ids = MapSet.new(["id1", "id2"])
      result = action.payload.(ids)
      assert result == %{ids: ["id1", "id2"]}
    end

    test "restricted key is configured true" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      assert action.restricted == true
    end

    test "restricted key is configured false" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_archive))
      assert action.restricted == false
    end
  end

  describe "all BulkAction.Ui keys (ComplexTestResource)" do
    test "ui label key is configured" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      ui = get_ui(action)
      assert ui.label == "Delete Selected"
    end

    test "ui icon key is configured" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      ui = get_ui(action)
      assert ui.icon == "hero-trash"
    end

    test "ui class key is configured" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      ui = get_ui(action)
      assert ui.class == "text-red-600"
    end

    test "ui extra key is configured" do
      actions = ResourceInfo.bulk_actions(ComplexTestResource)
      action = Enum.find(actions, &(&1.name == :bulk_delete))
      ui = get_ui(action)
      assert ui.extra == %{destructive: true}
    end
  end

  describe "BulkAction entity defaults" do
    test "restricted defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.BulkAction.opt_schema()
      restricted_config = Keyword.get(schema, :restricted)
      assert Keyword.get(restricted_config, :default) == false
    end

    test "visible defaults to :active in opt_schema" do
      schema = MishkaGervaz.Table.Entities.BulkAction.opt_schema()
      visible_config = Keyword.get(schema, :visible)
      assert Keyword.get(visible_config, :default) == :active
    end

    test "handler defaults to :parent in opt_schema" do
      schema = MishkaGervaz.Table.Entities.BulkAction.opt_schema()
      handler_config = Keyword.get(schema, :handler)
      assert Keyword.get(handler_config, :default) == :parent
    end
  end

  describe "BulkAction.Ui entity defaults" do
    test "extra defaults to empty map in opt_schema" do
      schema = MishkaGervaz.Table.Entities.BulkAction.Ui.opt_schema()
      extra_config = Keyword.get(schema, :extra)
      assert Keyword.get(extra_config, :default) == %{}
    end
  end

  describe "bulk_actions via TableInfo" do
    test "TableInfo.bulk_actions/1 returns all bulk actions" do
      actions = TableInfo.bulk_actions(ComplexTestResource)
      assert is_list(actions)
      action_names = Enum.map(actions, & &1.name)
      assert :bulk_delete in action_names
      assert :bulk_archive in action_names
    end
  end
end
