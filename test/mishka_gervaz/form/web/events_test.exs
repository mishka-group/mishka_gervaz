defmodule MishkaGervaz.Form.Web.EventsTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Web.Events
  import MishkaGervaz.Test.FormWebHelpers

  describe "delete_existing_file event" do
    test "removes file by id" do
      existing = %{
        cover: [
          %{id: "file-1", filename: "photo1.jpg"},
          %{id: "file-2", filename: "photo2.jpg"},
          %{id: "file-3", filename: "photo3.jpg"}
        ]
      }

      state = build_state(existing_files: existing)
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "cover", "file-id" => "file-2"},
          socket
        )

      updated_state = updated_socket.assigns.form_state
      assert length(updated_state.existing_files.cover) == 2

      ids = Enum.map(updated_state.existing_files.cover, & &1.id)
      assert "file-1" in ids
      assert "file-3" in ids
      refute "file-2" in ids
    end

    test "removes file by filename when no id" do
      existing = %{
        cover: [
          %{filename: "photo1.jpg"},
          %{filename: "photo2.jpg"}
        ]
      }

      state = build_state(existing_files: existing)
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "cover", "file-id" => "photo1.jpg"},
          socket
        )

      updated_state = updated_socket.assigns.form_state
      assert length(updated_state.existing_files.cover) == 1
      assert hd(updated_state.existing_files.cover).filename == "photo2.jpg"
    end

    test "removes file by name field" do
      existing = %{
        avatar: [%{name: "profile.png"}]
      }

      state = build_state(existing_files: existing)
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "avatar", "file-id" => "profile.png"},
          socket
        )

      assert updated_socket.assigns.form_state.existing_files.avatar == []
    end

    test "sets dirty? to true" do
      existing = %{cover: [%{id: "file-1", filename: "photo.jpg"}]}
      state = build_state(existing_files: existing, dirty?: false)
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "cover", "file-id" => "file-1"},
          socket
        )

      assert updated_socket.assigns.form_state.dirty?
    end

    test "handles empty list for upload key" do
      state = build_state(existing_files: %{cover: []})
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "cover", "file-id" => "nonexistent"},
          socket
        )

      assert updated_socket.assigns.form_state.existing_files.cover == []
    end

    test "handles missing upload key in existing_files" do
      state = build_state(existing_files: %{})
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "cover", "file-id" => "x"},
          socket
        )

      assert updated_socket.assigns.form_state.existing_files.cover == []
    end

    test "preserves files for other upload keys" do
      existing = %{
        cover: [%{id: "c1", filename: "cover.jpg"}],
        avatar: [%{id: "a1", filename: "avatar.png"}]
      }

      state = build_state(existing_files: existing)
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "cover", "file-id" => "c1"},
          socket
        )

      updated_files = updated_socket.assigns.form_state.existing_files
      assert updated_files.cover == []
      assert length(updated_files.avatar) == 1
    end

    test "handles non-existing atom via ArgumentError rescue" do
      state = build_state(existing_files: %{})
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle(
          "delete_existing_file",
          %{"upload" => "nonexistent_atom_xyz_99", "file-id" => "x"},
          socket
        )
    end
  end

  describe "cancel event" do
    test "sends form_cancelled message to parent" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} = Events.handle("cancel", %{}, socket)

      resource = state.static.resource
      assert_received {:form_cancelled, ^resource}
    end
  end

  describe "unknown event passthrough" do
    test "sends form_event to parent" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("custom_action", %{"key" => "val"}, socket)

      assert_received {:form_event, "custom_action", %{"key" => "val"}}
    end

    test "passes empty params" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} = Events.handle("my_event", %{}, socket)

      assert_received {:form_event, "my_event", %{}}
    end
  end

  describe "validate event" do
    test "returns noreply tuple" do
      state = build_state()
      socket = build_socket(state)

      result = Events.handle("validate", %{"form" => %{"title" => "test"}}, socket)
      assert {:noreply, _socket} = result
    end
  end

  describe "field_change event" do
    test "updates field_values" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle("field_change", %{"field" => "title", "value" => "new title"}, socket)

      updated_state = updated_socket.assigns.form_state
      assert updated_state.field_values[:title] == "new title"
    end

    test "sets dirty? to true" do
      state = build_state(dirty?: false)
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle("field_change", %{"field" => "title", "value" => "x"}, socket)

      assert updated_socket.assigns.form_state.dirty?
    end

    test "preserves other field values" do
      state = build_state(field_values: %{content: "existing"})
      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle("field_change", %{"field" => "title", "value" => "new"}, socket)

      updated_state = updated_socket.assigns.form_state
      assert updated_state.field_values[:title] == "new"
      assert updated_state.field_values[:content] == "existing"
    end

    test "handles non-existing field atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle(
          "field_change",
          %{"field" => "nonexistent_field_xyz_99", "value" => "x"},
          socket
        )
    end
  end

  describe "add_nested event" do
    test "sends add_nested_field message" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} = Events.handle("add_nested", %{"field" => "title"}, socket)

      assert_received {:add_nested_field, :title}
    end

    test "handles non-existing atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("add_nested", %{"field" => "nonexistent_nested_xyz_99"}, socket)
    end
  end

  describe "remove_nested event" do
    test "sends remove_nested_field message with parsed index" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("remove_nested", %{"field" => "title", "index" => "2"}, socket)

      assert_received {:remove_nested_field, :title, 2}
    end

    test "parses index as integer" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("remove_nested", %{"field" => "title", "index" => "0"}, socket)

      assert_received {:remove_nested_field, :title, 0}
    end
  end

  describe "goto_step event" do
    test "handles non-existing step atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("goto_step", %{"step" => "nonexistent_step_xyz_99"}, socket)
    end
  end

  describe "relation_search event" do
    test "handles non-existing field atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle(
          "relation_search",
          %{"field" => "nonexistent_rel_xyz_99", "query" => "test"},
          socket
        )
    end
  end

  describe "relation_clear event" do
    test "handles non-existing field atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle(
          "relation_clear",
          %{"field" => "nonexistent_rel_xyz_99"},
          socket
        )
    end
  end
end
