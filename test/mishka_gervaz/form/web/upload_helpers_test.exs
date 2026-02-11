defmodule MishkaGervaz.Form.Web.UploadHelpersTest do
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.UploadHelpers

  describe "parse_accept/1" do
    test "returns :any for nil" do
      assert UploadHelpers.parse_accept(nil) == :any
    end

    test "parses single type" do
      assert UploadHelpers.parse_accept("image/*") == ["image/*"]
    end

    test "parses comma-separated types" do
      assert UploadHelpers.parse_accept("image/*,.pdf,application/json") ==
               ["image/*", ".pdf", "application/json"]
    end

    test "trims whitespace" do
      assert UploadHelpers.parse_accept("image/* , .pdf , .doc") ==
               ["image/*", ".pdf", ".doc"]
    end

    test "rejects empty parts" do
      assert UploadHelpers.parse_accept("image/*,,,.pdf") == ["image/*", ".pdf"]
    end
  end

  describe "namespaced_upload_name/2" do
    test "combines upload name with component id" do
      assert UploadHelpers.namespaced_upload_name(:avatar, "post-form") == :avatar_post_form
    end

    test "replaces special characters with underscores" do
      assert UploadHelpers.namespaced_upload_name(:doc, "my.form-123") == :doc_my_form_123
    end

    test "handles atom component id" do
      assert UploadHelpers.namespaced_upload_name(:cover, :form_id) == :cover_form_id
    end
  end

  describe "has_uploads?/1" do
    test "returns true when uploads list is non-empty" do
      assert UploadHelpers.has_uploads?(%{uploads: [%{name: :avatar}]})
    end

    test "returns false for empty uploads list" do
      refute UploadHelpers.has_uploads?(%{uploads: []})
    end

    test "returns false when no uploads key" do
      refute UploadHelpers.has_uploads?(%{})
    end

    test "returns false for nil uploads" do
      refute UploadHelpers.has_uploads?(%{uploads: nil})
    end
  end

  describe "find_upload_for_field/2" do
    test "finds upload by field" do
      static = %{
        uploads: [%{name: :avatar, field: :profile_pic}, %{name: :doc, field: :document}]
      }

      result = UploadHelpers.find_upload_for_field(static, :profile_pic)
      assert result.name == :avatar
    end

    test "falls back to name when field doesn't match" do
      static = %{uploads: [%{name: :avatar, field: nil}, %{name: :doc, field: nil}]}
      result = UploadHelpers.find_upload_for_field(static, :avatar)
      assert result.name == :avatar
    end

    test "returns nil when no match" do
      static = %{uploads: [%{name: :avatar, field: :pic}]}
      assert UploadHelpers.find_upload_for_field(static, :nonexistent) == nil
    end

    test "returns nil for missing uploads key" do
      assert UploadHelpers.find_upload_for_field(%{}, :avatar) == nil
    end
  end

  describe "upload_error_to_string/1" do
    test "too_large" do
      assert UploadHelpers.upload_error_to_string(:too_large) == "File is too large"
    end

    test "too_many_files" do
      assert UploadHelpers.upload_error_to_string(:too_many_files) == "Too many files"
    end

    test "not_accepted" do
      assert UploadHelpers.upload_error_to_string(:not_accepted) == "File type not accepted"
    end

    test "external_client_failure" do
      assert UploadHelpers.upload_error_to_string(:external_client_failure) == "Upload failed"
    end

    test "unknown error" do
      assert UploadHelpers.upload_error_to_string(:some_other) == "Upload error: :some_other"
    end
  end

  describe "build_allow_upload_opts/2" do
    test "builds default opts" do
      config = %{}
      opts = UploadHelpers.build_allow_upload_opts(config, "form-1")

      assert Keyword.get(opts, :max_entries) == 1
      assert Keyword.get(opts, :max_file_size) == 8_000_000
      assert Keyword.get(opts, :auto_upload) == false
      refute Keyword.has_key?(opts, :accept)
    end

    test "includes configured values" do
      config = %{
        max_entries: 5,
        max_file_size: 20_000_000,
        auto_upload: true,
        accept: "image/*,.pdf"
      }

      opts = UploadHelpers.build_allow_upload_opts(config, "form-1")

      assert Keyword.get(opts, :max_entries) == 5
      assert Keyword.get(opts, :max_file_size) == 20_000_000
      assert Keyword.get(opts, :auto_upload) == true
      assert Keyword.get(opts, :accept) == ["image/*", ".pdf"]
    end

    test "includes chunk_size when configured" do
      config = %{chunk_size: 64_000}
      opts = UploadHelpers.build_allow_upload_opts(config, "form-1")
      assert Keyword.get(opts, :chunk_size) == 64_000
    end

    test "includes chunk_timeout when configured" do
      config = %{chunk_timeout: 30_000}
      opts = UploadHelpers.build_allow_upload_opts(config, "form-1")
      assert Keyword.get(opts, :chunk_timeout) == 30_000
    end

    test "omits nil optional values" do
      config = %{chunk_size: nil, external: nil, writer: nil}
      opts = UploadHelpers.build_allow_upload_opts(config, "form-1")

      refute Keyword.has_key?(opts, :chunk_size)
      refute Keyword.has_key?(opts, :external)
      refute Keyword.has_key?(opts, :writer)
    end
  end
end
