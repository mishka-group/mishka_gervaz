defmodule MishkaGervaz.DSL.RowActionsTest do
  @moduledoc """
  Tests for the row_actions DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo
  alias MishkaGervaz.Test.Resources.{Post, User, Comment, ComplexTestResource}

  # Helper to get the UI config from an action (handles list or single struct)
  defp get_ui(action) do
    case action.ui do
      [ui | _] -> ui
      ui when is_struct(ui) -> ui
      _ -> nil
    end
  end

  describe "row action definitions" do
    test "returns all row actions for a resource" do
      actions = ResourceInfo.row_actions(Post)
      assert is_list(actions)
      assert length(actions) > 0
    end

    test "each action is a RowAction struct" do
      actions = ResourceInfo.row_actions(Post)

      Enum.each(actions, fn action ->
        assert is_struct(action, MishkaGervaz.Table.Entities.RowAction)
      end)
    end

    test "retrieves specific action by name" do
      action = ResourceInfo.row_action(Post, :show)
      assert action.name == :show
    end

    test "returns nil for non-existent action" do
      action = ResourceInfo.row_action(Post, :non_existent)
      assert action == nil
    end
  end

  describe "link type actions" do
    test "link action has correct type" do
      action = ResourceInfo.row_action(Post, :show)
      assert action.type == :link
    end

    test "link action has path function" do
      action = ResourceInfo.row_action(Post, :show)
      assert is_function(action.path, 1)
    end

    test "link action path function works correctly" do
      action = ResourceInfo.row_action(Post, :show)
      record = %{id: "test-uuid-123"}
      path = action.path.(record)
      assert path == "/admin/posts/test-uuid-123"
    end

    test "edit action generates correct path" do
      action = ResourceInfo.row_action(Post, :edit)
      record = %{id: "uuid-456"}
      path = action.path.(record)
      assert path == "/admin/posts/uuid-456/edit"
    end

    test "User show action with ui configuration" do
      action = ResourceInfo.row_action(User, :show)
      ui = get_ui(action)
      assert action.type == :link
      assert ui.label == "View"
      assert ui.icon == "hero-eye"
    end

    test "User edit action with ui configuration" do
      action = ResourceInfo.row_action(User, :edit)
      ui = get_ui(action)
      assert ui.label == "Edit"
      assert ui.icon == "hero-pencil"
    end
  end

  describe "event type actions" do
    test "event action has correct type" do
      action = ResourceInfo.row_action(Post, :publish)
      assert action.type == :event
    end

    test "event action has event name" do
      action = ResourceInfo.row_action(Post, :publish)
      assert action.event == "publish_post"
    end

    test "event action has visibility function" do
      action = ResourceInfo.row_action(Post, :publish)
      assert is_function(action.visible, 2)
    end

    test "event action visibility function works - visible for drafts" do
      action = ResourceInfo.row_action(Post, :publish)
      draft_record = %{status: :draft}
      state = %{}
      assert action.visible.(draft_record, state) == true
    end

    test "event action visibility function works - hidden for published" do
      action = ResourceInfo.row_action(Post, :publish)
      published_record = %{status: :published}
      state = %{}
      assert action.visible.(published_record, state) == false
    end

    test "event action ui configuration" do
      action = ResourceInfo.row_action(Post, :publish)
      ui = get_ui(action)
      assert ui.label == "Publish"
      assert ui.icon == "hero-rocket-launch"
    end

    test "Comment approve event action" do
      action = ResourceInfo.row_action(Comment, :approve)
      ui = get_ui(action)
      assert action.type == :event
      assert action.event == "approve_comment"
      assert ui.icon == "hero-check"
    end

    test "Comment approve visibility - visible for unapproved" do
      action = ResourceInfo.row_action(Comment, :approve)
      record = %{approved: false}
      assert action.visible.(record, %{}) == true
    end

    test "Comment approve visibility - hidden for approved" do
      action = ResourceInfo.row_action(Comment, :approve)
      record = %{approved: true}
      assert action.visible.(record, %{}) == false
    end
  end

  describe "destroy type actions" do
    test "destroy action has correct type" do
      action = ResourceInfo.row_action(Post, :delete)
      assert action.type == :destroy
    end

    test "destroy action has confirm message" do
      action = ResourceInfo.row_action(Post, :delete)
      assert action.confirm == "Are you sure you want to delete this post?"
    end

    test "User destroy action configuration" do
      action = ResourceInfo.row_action(User, :delete)
      ui = get_ui(action)
      assert action.type == :destroy
      assert action.confirm == "Are you sure you want to delete this user?"
      assert ui.label == "Delete"
      assert ui.icon == "hero-trash"
    end

    test "Comment destroy action" do
      action = ResourceInfo.row_action(Comment, :delete)
      assert action.type == :destroy
      assert action.confirm == "Delete this comment?"
    end
  end

  describe "row action counts" do
    test "Post has correct number of row actions" do
      actions = ResourceInfo.row_actions(Post)
      assert length(actions) == 6
    end

    test "User has correct number of row actions" do
      actions = ResourceInfo.row_actions(User)
      assert length(actions) == 3
    end

    test "Comment has correct number of row actions" do
      actions = ResourceInfo.row_actions(Comment)
      assert length(actions) == 2
    end
  end

  describe "custom render function" do
    test "action with render function arity 1 has render field set" do
      action = ResourceInfo.row_action(Post, :custom_view)
      assert is_function(action.render, 1)
    end

    test "action with render function arity 2 has render field set" do
      action = ResourceInfo.row_action(Post, :custom_action)
      assert is_function(action.render, 2)
    end

    test "render function arity 1 returns HEEx template" do
      action = ResourceInfo.row_action(Post, :custom_view)
      record = %{id: "test-123", title: "Test Post"}
      result = action.render.(record)
      assert is_struct(result, Phoenix.LiveView.Rendered)
    end

    test "render function arity 2 returns HEEx template with action access" do
      action = ResourceInfo.row_action(Post, :custom_action)
      record = %{id: "test-456", title: "Another Post"}
      result = action.render.(record, action)
      assert is_struct(result, Phoenix.LiveView.Rendered)
    end

    test "action without render function has nil render field" do
      action = ResourceInfo.row_action(Post, :show)
      assert action.render == nil
    end
  end

  describe "update type actions" do
    test "update action has correct type" do
      action = ResourceInfo.row_action(ComplexTestResource, :publish_now)
      assert action.type == :update
    end

    test "update action has action field with atom" do
      action = ResourceInfo.row_action(ComplexTestResource, :publish_now)
      assert action.action == :publish
    end

    test "update action has action field with tuple for multitenancy" do
      action = ResourceInfo.row_action(ComplexTestResource, :feature)
      assert action.action == {:master_feature, :feature}
    end

    test "update action with confirm message" do
      action = ResourceInfo.row_action(ComplexTestResource, :feature)
      assert action.confirm == "Feature this post?"
    end

    test "update action ui configuration" do
      action = ResourceInfo.row_action(ComplexTestResource, :publish_now)
      ui = get_ui(action)
      assert ui.label == "Publish"
      assert ui.icon == "hero-rocket-launch"
    end

    test "update action visibility setting" do
      action = ResourceInfo.row_action(ComplexTestResource, :publish_now)
      assert action.visible == :active
    end

    test "update action restricted setting" do
      action = ResourceInfo.row_action(ComplexTestResource, :publish_now)
      assert action.restricted == true
    end
  end

  describe "destroy type actions with explicit action" do
    test "destroy action has correct type" do
      action = ResourceInfo.row_action(ComplexTestResource, :remove)
      assert action.type == :destroy
    end

    test "destroy action has action field with tuple for multitenancy" do
      action = ResourceInfo.row_action(ComplexTestResource, :remove)
      assert action.action == {:master_destroy, :destroy}
    end

    test "destroy action with confirm message" do
      action = ResourceInfo.row_action(ComplexTestResource, :remove)
      assert action.confirm == "Remove this post?"
    end

    test "destroy action ui configuration" do
      action = ResourceInfo.row_action(ComplexTestResource, :remove)
      ui = get_ui(action)
      assert ui.label == "Remove"
      assert ui.icon == "hero-x-mark"
    end

    test "destroy action without explicit action uses source" do
      # The :delete action doesn't have explicit action field
      action = ResourceInfo.row_action(ComplexTestResource, :delete)
      assert action.type == :destroy
      assert action.action == nil
    end
  end

  describe "edit type actions" do
    test "edit action has correct type" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_form)
      assert action.type == :edit
    end

    test "edit action has :active visibility" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_form)
      assert action.visible == :active
    end

    test "edit action ui configuration" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_form)
      ui = get_ui(action)
      assert ui.label == "Edit Form"
      assert ui.icon == "hero-pencil-square"
    end

    test "edit action with js hook has function" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_modal)
      assert is_function(action.js, 1)
    end

    test "edit action js hook returns JS struct" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_modal)
      result = action.js.(%{id: "test-123"})
      assert is_struct(result, Phoenix.LiveView.JS)
    end

    test "edit action without js has nil js field" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_form)
      assert action.js == nil
    end

    test "edit action resolves type_module to Action.Edit" do
      action = ResourceInfo.row_action(ComplexTestResource, :edit_form)
      assert action.type_module == MishkaGervaz.Table.Types.Action.Edit
    end
  end

  describe "js field on row actions" do
    test "js is in opt_schema" do
      schema = MishkaGervaz.Table.Entities.RowAction.opt_schema()
      js_config = Keyword.get(schema, :js)
      assert js_config != nil
      assert Keyword.get(js_config, :type) == {:fun, 1}
    end

    test "non-edit actions have nil js by default" do
      action = ResourceInfo.row_action(ComplexTestResource, :show)
      assert action.js == nil
    end
  end

  describe "RowAction entity defaults" do
    test "restricted defaults to false in opt_schema" do
      schema = MishkaGervaz.Table.Entities.RowAction.opt_schema()
      restricted_config = Keyword.get(schema, :restricted)
      assert Keyword.get(restricted_config, :default) == false
    end

    test "visible defaults to :active in opt_schema" do
      schema = MishkaGervaz.Table.Entities.RowAction.opt_schema()
      visible_config = Keyword.get(schema, :visible)
      assert Keyword.get(visible_config, :default) == :active
    end

    test "target is no longer in opt_schema" do
      schema = MishkaGervaz.Table.Entities.RowAction.opt_schema()
      assert Keyword.get(schema, :target) == nil
    end
  end

  describe "RowAction.Ui entity defaults" do
    test "extra defaults to empty map in opt_schema" do
      schema = MishkaGervaz.Table.Entities.RowAction.Ui.opt_schema()
      extra_config = Keyword.get(schema, :extra)
      assert Keyword.get(extra_config, :default) == %{}
    end
  end

  describe "row_actions via TableInfo" do
    test "TableInfo.row_actions/1 returns all row actions" do
      actions = TableInfo.row_actions(ComplexTestResource)
      assert is_list(actions)
      action_names = Enum.map(actions, & &1.name)
      assert :show in action_names
      assert :edit in action_names
    end

    test "TableInfo.row_action/2 returns specific action" do
      action = TableInfo.row_action(ComplexTestResource, :show)
      assert action.name == :show
    end
  end
end
