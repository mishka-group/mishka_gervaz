defmodule MishkaGervaz.Form.Web.DataLoaderTest do
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.DataLoader
  import MishkaGervaz.Test.FormWebHelpers

  describe "handle_async_result :load_record success" do
    test "sets loading to loaded" do
      state = build_state(loading: :loading, mode: :update)
      socket = build_socket(state)

      form = %{source: %{source: %{data: %{id: "1", title: "Post"}}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      assert updated_socket.assigns.form_state.loading == :loaded
    end

    test "extracts existing files from record string field" do
      uploads = [upload_config(:cover)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", cover: "photo.jpg", title: "Post"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      cover_files = updated_socket.assigns.form_state.existing_files[:cover]
      assert length(cover_files) == 1
      assert hd(cover_files).filename == "photo.jpg"
    end

    test "extracts existing files from record list field" do
      uploads = [upload_config(:cover)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      files = [
        %{filename: "a.jpg", id: "1"},
        %{filename: "b.jpg", id: "2"},
        %{filename: "c.jpg", id: "3"}
      ]

      record = %{id: "1", cover: files, title: "Post"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      cover_files = updated_socket.assigns.form_state.existing_files[:cover]
      assert length(cover_files) == 3
      assert Enum.all?(cover_files, &Map.has_key?(&1, :filename))
    end

    test "normalizes name field to filename" do
      uploads = [upload_config(:avatar)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", avatar: [%{name: "profile.png", id: "p1"}]}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      avatar_files = updated_socket.assigns.form_state.existing_files[:avatar]
      assert hd(avatar_files).filename == "profile.png"
    end

    test "normalizes string-keyed file maps" do
      uploads = [upload_config(:doc)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", doc: [%{"filename" => "report.pdf", "id" => "d1"}]}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      doc_files = updated_socket.assigns.form_state.existing_files[:doc]
      assert hd(doc_files).filename == "report.pdf"
      assert hd(doc_files).id == "d1"
    end

    test "normalizes string-keyed name maps" do
      uploads = [upload_config(:doc)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", doc: [%{"name" => "report.pdf", "id" => "d1"}]}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      doc_files = updated_socket.assigns.form_state.existing_files[:doc]
      assert hd(doc_files).filename == "report.pdf"
    end

    test "handles nil record field as empty list" do
      uploads = [upload_config(:cover)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", cover: nil, title: "Post"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      assert updated_socket.assigns.form_state.existing_files[:cover] == []
    end

    test "handles single map value" do
      uploads = [upload_config(:cover)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", cover: %{filename: "single.jpg", id: "s1"}, title: "Post"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      cover_files = updated_socket.assigns.form_state.existing_files[:cover]
      assert length(cover_files) == 1
      assert hd(cover_files).filename == "single.jpg"
    end

    test "uses field option when set on upload config" do
      uploads = [upload_config(:documents, field: :attachments)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", attachments: [%{filename: "doc.pdf"}], documents: "wrong"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      doc_files = updated_socket.assigns.form_state.existing_files[:documents]
      assert hd(doc_files).filename == "doc.pdf"
    end

    test "uses existing option as atom field" do
      uploads = [upload_config(:cover, existing: :media_files)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", media_files: [%{filename: "media.jpg"}], cover: "wrong"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      cover_files = updated_socket.assigns.form_state.existing_files[:cover]
      assert hd(cover_files).filename == "media.jpg"
    end

    test "uses existing option as function" do
      extractor = fn record -> [%{filename: "from_fn_#{record.id}.jpg"}] end
      uploads = [upload_config(:cover, existing: extractor)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "42", cover: "wrong"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      cover_files = updated_socket.assigns.form_state.existing_files[:cover]
      assert hd(cover_files).filename == "from_fn_42.jpg"
    end

    test "returns empty map when form has no record data" do
      uploads = [upload_config(:cover)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      form = %{source: %{source: %{data: nil}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      assert updated_socket.assigns.form_state.existing_files == %{}
    end

    test "returns empty map when no uploads configured" do
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: []])
      socket = build_socket(state)

      record = %{id: "1", cover: "something"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      assert updated_socket.assigns.form_state.existing_files == %{}
    end

    test "handles multiple upload configs" do
      uploads = [
        upload_config(:cover),
        upload_config(:avatar),
        upload_config(:documents, field: :attachments)
      ]

      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{
        id: "1",
        cover: "cover.jpg",
        avatar: [%{filename: "me.png"}],
        attachments: [%{filename: "a.pdf"}, %{filename: "b.pdf"}]
      }

      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      files = updated_socket.assigns.form_state.existing_files
      assert length(files[:cover]) == 1
      assert length(files[:avatar]) == 1
      assert length(files[:documents]) == 2
    end

    test "normalizes plain string values" do
      uploads = [upload_config(:cover)]
      state = build_state(loading: :loading, mode: :update, static_opts: [uploads: uploads])
      socket = build_socket(state)

      record = %{id: "1", cover: "just-a-string.jpg"}
      form = %{source: %{source: %{data: record}}}

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      cover_files = updated_socket.assigns.form_state.existing_files[:cover]
      assert hd(cover_files).filename == "just-a-string.jpg"
    end
  end

  describe "handle_async_result :load_record error" do
    test "sets loading to error on failure" do
      state = build_state(loading: :loading)
      socket = build_socket(state)

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:ok, {:error, :not_found}}, socket)

      assert updated_socket.assigns.form_state.loading == :error
    end

    test "sets loading to error on exit" do
      state = build_state(loading: :loading)
      socket = build_socket(state)

      updated_socket =
        DataLoader.Default.handle_async_result(:load_record, {:exit, :timeout}, socket)

      assert updated_socket.assigns.form_state.loading == :error
    end

    test "sets loading to error on crash" do
      state = build_state(loading: :loading)
      socket = build_socket(state)

      updated_socket =
        DataLoader.Default.handle_async_result(
          :load_record,
          {:exit, {:shutdown, :brutal_kill}},
          socket
        )

      assert updated_socket.assigns.form_state.loading == :error
    end
  end

  describe "handle_async_result :load_relation" do
    test "stores relation options" do
      state = build_state()
      socket = build_socket(state)

      options = [%{value: "1", label: "Option A"}, %{value: "2", label: "Option B"}]

      updated_socket =
        DataLoader.Default.handle_async_result(
          {:load_relation, :user_id},
          {:ok, {:ok, options, false}},
          socket
        )

      rel_opts = updated_socket.assigns.form_state.relation_options[:user_id]
      assert rel_opts.options == options
      assert rel_opts.has_more? == false
      assert rel_opts.page == 1
    end

    test "stores has_more? flag" do
      state = build_state()
      socket = build_socket(state)

      updated_socket =
        DataLoader.Default.handle_async_result(
          {:load_relation, :category_id},
          {:ok, {:ok, [%{value: "1", label: "Cat"}], true}},
          socket
        )

      rel_opts = updated_socket.assigns.form_state.relation_options[:category_id]
      assert rel_opts.has_more?
    end
  end

  describe "handle_async_result :search_relation" do
    test "stores search results" do
      state = build_state()
      socket = build_socket(state)

      results = [%{value: "3", label: "Match A"}]

      updated_socket =
        DataLoader.Default.handle_async_result(
          {:search_relation, :tag_id},
          {:ok, {:ok, results, false}},
          socket
        )

      rel_opts = updated_socket.assigns.form_state.relation_options[:tag_id]
      assert rel_opts.options == results
    end
  end

  describe "handle_async_result unknown task" do
    test "returns socket unchanged" do
      state = build_state()
      socket = build_socket(state)

      result = DataLoader.Default.handle_async_result(:unknown_task, {:ok, :anything}, socket)
      assert result == socket
    end

    test "handles tuple task names" do
      state = build_state()
      socket = build_socket(state)

      result =
        DataLoader.Default.handle_async_result(
          {:unknown_tuple, :field},
          {:ok, :anything},
          socket
        )

      assert result == socket
    end
  end
end
