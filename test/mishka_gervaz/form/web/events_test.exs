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

      state =
        build_state(existing_files: existing, static_opts: [uploads: [upload_config(:cover)]])

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

      state =
        build_state(existing_files: existing, static_opts: [uploads: [upload_config(:cover)]])

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

      state =
        build_state(existing_files: existing, static_opts: [uploads: [upload_config(:avatar)]])

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

      state =
        build_state(
          existing_files: existing,
          dirty?: false,
          static_opts: [uploads: [upload_config(:cover)]]
        )

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
      state =
        build_state(existing_files: %{cover: []}, static_opts: [uploads: [upload_config(:cover)]])

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
      state = build_state(existing_files: %{}, static_opts: [uploads: [upload_config(:cover)]])
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

      state =
        build_state(
          existing_files: existing,
          static_opts: [uploads: [upload_config(:cover), upload_config(:avatar)]]
        )

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
    test "resets form state without sending message when no on_cancel hook" do
      state = build_state(static_opts: [resource: MishkaGervaz.Test.Resources.FormPost])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)

      updated_state = updated_socket.assigns.form_state
      assert updated_state.errors == %{}
      assert updated_state.dirty? == false
      assert updated_state.mode == :create
      refute_received {:form_cancelled, _}
    end

    test "sends form_cancelled message when on_cancel hook is configured" do
      hook = fn _state -> nil end

      state =
        build_state(
          static_opts: [
            resource: MishkaGervaz.Test.Resources.FormPost,
            hooks: %{on_cancel: hook}
          ]
        )

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

    test "on_validate hook is called and can modify params" do
      test_pid = self()

      hook = fn params, _state ->
        send(test_pid, :on_validate_called)
        put_in(params, ["form", "title"], "hook-modified")
      end

      state = build_state(static_opts: [hooks: %{on_validate: hook}])
      socket = build_socket(state)

      Events.handle("validate", %{"form" => %{"title" => "original"}}, socket)

      assert_received :on_validate_called
    end

    test "on_validate hook returning non-map leaves params unchanged" do
      hook = fn _params, _state -> nil end

      state = build_state(static_opts: [hooks: %{on_validate: hook}])
      socket = build_socket(state)

      assert {:noreply, _socket} = Events.handle("validate", %{"form" => %{"title" => "x"}}, socket)
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

    test "calls on_change hook with field atom, value, and state" do
      test_pid = self()
      hook = fn field, value, _state -> send(test_pid, {:on_change, field, value}) end

      state = build_state(static_opts: [hooks: %{on_change: hook}])
      socket = build_socket(state)

      Events.handle("field_change", %{"field" => "title", "value" => "typed"}, socket)

      assert_received {:on_change, :title, "typed"}
    end

    test "halts field update when on_change hook returns {:halt, state}" do
      hook = fn _field, _value, state -> {:halt, state} end

      state =
        build_state(
          static_opts: [hooks: %{on_change: hook}],
          field_values: %{title: "original"}
        )

      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle("field_change", %{"field" => "title", "value" => "blocked"}, socket)

      assert updated_socket.assigns.form_state.field_values[:title] == "original"
    end

    test "hook returning {:halt, state} can carry modified state" do
      hook = fn field, _value, state ->
        modified = put_in(state.field_values[field], "hook-modified")
        {:halt, modified}
      end

      state =
        build_state(field_values: %{title: "original"}, static_opts: [hooks: %{on_change: hook}])

      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle("field_change", %{"field" => "title", "value" => "blocked"}, socket)

      assert updated_socket.assigns.form_state.field_values[:title] == "hook-modified"
    end
  end

  describe "combobox_select event - on_change hook" do
    test "calls on_change hook with field atom, value, and state" do
      test_pid = self()
      hook = fn field, value, _state -> send(test_pid, {:on_change, field, value}) end

      state = build_state(static_opts: [hooks: %{on_change: hook}])
      socket = build_socket(state)

      Events.handle("combobox_select", %{"field" => "status", "value" => "draft"}, socket)

      assert_received {:on_change, :status, "draft"}
    end

    test "halts combobox update when on_change hook returns {:halt, state}" do
      hook = fn _field, _value, state -> {:halt, state} end

      state =
        build_state(
          static_opts: [hooks: %{on_change: hook}],
          field_values: %{status: "published"}
        )

      socket = build_socket(state)

      {:noreply, updated_socket} =
        Events.handle("combobox_select", %{"field" => "status", "value" => "draft"}, socket)

      assert updated_socket.assigns.form_state.field_values[:status] == "published"
    end
  end

  describe "add_nested event" do
    test "returns noreply when form is nil" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} = Events.handle("add_nested", %{"field" => "title"}, socket)
    end

    test "handles non-existing atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("add_nested", %{"field" => "nonexistent_nested_xyz_99"}, socket)
    end
  end

  describe "remove_nested event" do
    test "returns noreply when form is nil" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle("remove_nested", %{"field" => "title", "index" => "2"}, socket)
    end

    test "handles non-existing atom gracefully" do
      state = build_state()
      socket = build_socket(state)

      {:noreply, _socket} =
        Events.handle(
          "remove_nested",
          %{"field" => "nonexistent_nested_xyz_99", "index" => "0"},
          socket
        )
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

  describe "save event — submit button server-side enforcement" do
    test "save blocked when create button is nil" do
      submit = %{create: nil, update: nil, cancel: nil, position: :bottom}
      state = build_state(mode: :create, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.mode == :create
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked when create button disabled is true" do
      submit = %{
        create: %{label: "Create", disabled: true, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :create, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked when create button disabled is function returning true" do
      submit = %{
        create: %{
          label: "Create",
          disabled: fn _state -> true end,
          restricted: false,
          visible: true
        },
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :create, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked when create button visible is false" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: false},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :create, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked when create button visible function returns false" do
      submit = %{
        create: %{
          label: "Create",
          disabled: false,
          restricted: false,
          visible: fn _s -> false end
        },
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :create, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked when create button restricted true and user not master" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: true, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :create, master_user?: false, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save allowed when create button restricted true and user IS master" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: true, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state =
        build_state(
          mode: :create,
          master_user?: true,
          static_opts: [submit: submit, resource: MishkaGervaz.Test.Resources.FormPost]
        )

      socket = build_socket(state)

      {:noreply, _updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
    end

    test "save blocked when restricted function returns true" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: fn _s -> true end, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :create, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked on update mode when update button is disabled" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: true, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :update, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked on update mode when update button not visible" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: false},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :update, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save blocked on update mode when update button is nil" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: nil,
        cancel: nil,
        position: :bottom
      }

      state = build_state(mode: :update, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save uses update button when mode is update, not create button" do
      submit = %{
        create: %{label: "Create", disabled: true, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state =
        build_state(
          mode: :update,
          static_opts: [submit: submit, resource: MishkaGervaz.Test.Resources.FormPost]
        )

      socket = build_socket(state)

      {:noreply, _updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
    end

    test "save blocked when update button disabled via function based on state" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{
          label: "Update",
          disabled: fn state -> not state.master_user? end,
          restricted: false,
          visible: true
        },
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(mode: :update, master_user?: false, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
    end

    test "save allowed when update button disabled function returns false" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{
          label: "Update",
          disabled: fn _state -> false end,
          restricted: false,
          visible: true
        },
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom
      }

      state =
        build_state(
          mode: :update,
          static_opts: [submit: submit, resource: MishkaGervaz.Test.Resources.FormPost]
        )

      socket = build_socket(state)

      {:noreply, _updated_socket} = Events.handle("save", %{"form" => %{}}, socket)
    end
  end

  describe "cancel event — submit button server-side enforcement" do
    test "cancel blocked when cancel button is nil" do
      submit = %{create: nil, update: nil, cancel: nil, position: :bottom}
      state = build_state(static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state.dirty? == false
      assert updated_socket.assigns.form_state.mode == :create
    end

    test "cancel blocked when cancel button disabled is true" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: true, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state == state
    end

    test "cancel blocked when cancel button visible is false" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: false},
        position: :bottom
      }

      state = build_state(static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state == state
    end

    test "cancel blocked when cancel button restricted true and user not master" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: true, visible: true},
        position: :bottom
      }

      state = build_state(master_user?: false, static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state == state
    end

    test "cancel allowed when cancel button restricted true and user IS master" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: true, visible: true},
        position: :bottom
      }

      state =
        build_state(
          master_user?: true,
          static_opts: [submit: submit, resource: MishkaGervaz.Test.Resources.FormPost]
        )

      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      refute updated_socket.assigns.form_state == state
    end

    test "cancel blocked when cancel disabled function returns true" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: fn _s -> true end, restricted: false, visible: true},
        position: :bottom
      }

      state = build_state(static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state == state
    end

    test "cancel blocked when cancel visible function returns false" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{
          label: "Cancel",
          disabled: false,
          restricted: false,
          visible: fn _s -> false end
        },
        position: :bottom
      }

      state = build_state(static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state == state
    end

    test "cancel blocked when cancel restricted function returns true" do
      submit = %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: fn _s -> true end, visible: true},
        position: :bottom
      }

      state = build_state(static_opts: [submit: submit])
      socket = build_socket(state)

      {:noreply, updated_socket} = Events.handle("cancel", %{}, socket)
      assert updated_socket.assigns.form_state == state
    end
  end
end
