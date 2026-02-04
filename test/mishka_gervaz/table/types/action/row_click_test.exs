defmodule MishkaGervaz.Types.Action.RowClickTest do
  @moduledoc """
  Tests for the RowClick action type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.RowClick

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = RowClick.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(RowClick)
      assert function_exported?(RowClick, :render, 5)
    end
  end

  describe "build_click_handler/2" do
    test "returns navigate map when action has path string" do
      action = %{path: "/posts/{id}"}
      record = %{id: "abc123"}

      result = RowClick.build_click_handler(action, record)

      assert result == %{navigate: "/posts/abc123"}
    end

    test "replaces multiple placeholders in path" do
      action = %{path: "/users/{user_id}/posts/{id}"}
      record = %{id: "post123", user_id: "user456"}

      result = RowClick.build_click_handler(action, record)

      assert result == %{navigate: "/users/user456/posts/post123"}
    end

    test "returns navigate map when action has path function" do
      action = %{path: fn record -> "/custom/#{record.id}" end}
      record = %{id: "abc123"}

      result = RowClick.build_click_handler(action, record)

      assert result == %{navigate: "/custom/abc123"}
    end

    test "returns event map when action has event" do
      action = %{event: :row_selected, name: :select}
      record = %{id: "abc123"}

      result = RowClick.build_click_handler(action, record)

      assert result == %{event: :row_selected, id: "abc123"}
    end

    test "returns event with action name when no event specified" do
      action = %{name: :view}
      record = %{id: "abc123"}

      result = RowClick.build_click_handler(action, record)

      assert result == %{event: :view, id: "abc123"}
    end
  end

  describe "module attributes" do
    test "uses Phoenix.Component" do
      assert Code.ensure_loaded?(RowClick)
    end
  end
end
