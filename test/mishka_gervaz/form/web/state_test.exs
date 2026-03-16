defmodule MishkaGervaz.Form.Web.StateTest do
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State
  import MishkaGervaz.Test.FormWebHelpers

  describe "existing_files field" do
    test "defaults to empty map" do
      state = build_state()
      assert state.existing_files == %{}
    end

    test "can be initialized with files" do
      files = %{cover: [%{filename: "photo.jpg", id: "123"}]}
      state = build_state(existing_files: files)
      assert state.existing_files == files
    end

    test "supports multiple upload keys" do
      files = %{
        cover: [%{filename: "cover.jpg"}],
        avatar: [%{filename: "me.png"}],
        documents: [%{filename: "doc1.pdf"}, %{filename: "doc2.pdf"}]
      }

      state = build_state(existing_files: files)
      assert map_size(state.existing_files) == 3
      assert length(state.existing_files.documents) == 2
    end
  end

  describe "update/2 existing_files" do
    test "sets existing_files" do
      state = build_state()
      files = %{cover: [%{filename: "photo.jpg", id: "123"}]}
      updated = State.update(state, existing_files: files)
      assert updated.existing_files == files
    end

    test "preserves existing_files when updating other fields" do
      files = %{cover: [%{filename: "a.jpg"}]}
      state = build_state(existing_files: files)

      updated = State.update(state, dirty?: true)
      assert updated.existing_files == files
      assert updated.dirty?
    end

    test "replaces existing_files completely" do
      old_files = %{cover: [%{filename: "old.jpg"}]}
      new_files = %{cover: [%{filename: "new.jpg"}], avatar: [%{filename: "me.png"}]}
      state = build_state(existing_files: old_files)

      updated = State.update(state, existing_files: new_files)
      assert updated.existing_files == new_files
    end

    test "clears existing_files" do
      state = build_state(existing_files: %{cover: [%{filename: "x.jpg"}]})
      updated = State.update(state, existing_files: %{})
      assert updated.existing_files == %{}
    end
  end

  describe "upload_state field" do
    test "defaults to empty map" do
      state = build_state()
      assert state.upload_state == %{}
    end

    test "can store consumed upload results" do
      state = build_state()

      uploaded = %{
        cover: [%{path: "/tmp/file.jpg", client_name: "photo.jpg", client_type: "image/jpeg"}]
      }

      updated = State.update(state, upload_state: uploaded)
      assert updated.upload_state == uploaded
    end

    test "multiple upload keys in upload_state" do
      state = build_state()

      uploaded = %{
        cover: [%{path: "/tmp/a.jpg", client_name: "a.jpg"}],
        documents: [
          %{path: "/tmp/b.pdf", client_name: "b.pdf"},
          %{path: "/tmp/c.pdf", client_name: "c.pdf"}
        ]
      }

      updated = State.update(state, upload_state: uploaded)
      assert length(updated.upload_state.documents) == 2
    end
  end

  describe "Static struct uploads" do
    test "stores upload configs in static" do
      uploads = [upload_config(:cover), upload_config(:documents)]
      state = build_state(static_opts: [uploads: uploads])

      assert length(state.static.uploads) == 2
    end

    test "empty uploads list by default" do
      state = build_state()
      assert state.static.uploads == []
    end

    test "upload config has all required fields" do
      config = upload_config(:avatar, accept: "image/*", max_entries: 3, style: :file_input)

      assert config.name == :avatar
      assert config.accept == "image/*"
      assert config.max_entries == 3
      assert config.style == :file_input
    end
  end

  describe "preload_aliases field" do
    test "defaults to empty map" do
      state = build_state()
      assert state.preload_aliases == %{}
    end

    test "can be initialized with aliases" do
      aliases = %{category: :master_category, tags: :master_tags}
      state = build_state(preload_aliases: aliases)
      assert state.preload_aliases == aliases
    end

    test "preserves preload_aliases when updating other fields" do
      aliases = %{category: :tenant_category}
      state = build_state(preload_aliases: aliases)

      updated = State.update(state, dirty?: true)
      assert updated.preload_aliases == aliases
      assert updated.dirty?
    end

    test "can update preload_aliases" do
      state = build_state(preload_aliases: %{old: :old_source})
      updated = State.update(state, preload_aliases: %{new: :new_source})
      assert updated.preload_aliases == %{new: :new_source}
    end
  end

  describe "mode and loading" do
    test "defaults to create mode" do
      state = build_state()
      assert state.mode == :create
    end

    test "can update to update mode" do
      state = build_state()
      updated = State.update(state, mode: :update)
      assert updated.mode == :update
    end

    test "loading transitions" do
      state = build_state(loading: :initial)
      assert state.loading == :initial

      state = State.update(state, loading: :loading)
      assert state.loading == :loading

      state = State.update(state, loading: :loaded)
      assert state.loading == :loaded
    end

    test "dirty? starts as false" do
      state = build_state()
      refute state.dirty?
    end

    test "dirty? set to true on change" do
      state = build_state()
      updated = State.update(state, dirty?: true)
      assert updated.dirty?
    end
  end

  describe "combined state updates" do
    test "updates multiple fields atomically" do
      state = build_state()

      updated =
        State.update(state,
          mode: :update,
          loading: :loaded,
          dirty?: true,
          existing_files: %{cover: [%{filename: "x.jpg"}]},
          upload_state: %{cover: [%{path: "/tmp/y.jpg"}]}
        )

      assert updated.mode == :update
      assert updated.loading == :loaded
      assert updated.dirty?
      assert map_size(updated.existing_files) == 1
      assert map_size(updated.upload_state) == 1
    end
  end
end
