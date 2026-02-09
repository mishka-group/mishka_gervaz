defmodule MishkaGervaz.Form.DSL.UploadsTest do
  @moduledoc """
  Tests for the form uploads DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    MinimalForm
  }

  describe "upload count" do
    test "FormPost has 1 upload" do
      uploads = FormInfo.uploads(FormPost)
      assert length(uploads) == 1
    end

    test "MinimalForm has no uploads" do
      uploads = FormInfo.uploads(MinimalForm)
      assert uploads == []
    end
  end

  describe "upload config" do
    setup do
      [upload: hd(FormInfo.uploads(FormPost))]
    end

    test "name is :cover", %{upload: upload} do
      assert upload.name == :cover
    end

    test "accept", %{upload: upload} do
      assert upload.accept == "image/*"
    end

    test "max_entries", %{upload: upload} do
      assert upload.max_entries == 1
    end

    test "max_file_size", %{upload: upload} do
      assert upload.max_file_size == 5_000_000
    end

    test "show_preview", %{upload: upload} do
      assert upload.show_preview == true
    end

    test "auto_upload", %{upload: upload} do
      assert upload.auto_upload == true
    end

    test "dropzone_text", %{upload: upload} do
      assert upload.dropzone_text == "Drop image here"
    end
  end

  describe "upload UI" do
    setup do
      [upload: hd(FormInfo.uploads(FormPost))]
    end

    test "label", %{upload: upload} do
      assert upload.ui.label == "Cover Image"
    end

    test "icon", %{upload: upload} do
      assert upload.ui.icon == "hero-photo"
    end

    test "class", %{upload: upload} do
      assert upload.ui.class == "border-dashed"
    end

    test "preview_class", %{upload: upload} do
      assert upload.ui.preview_class == "w-32 h-32"
    end

    test "extra", %{upload: upload} do
      assert upload.ui.extra == %{rounded: true}
    end
  end

  describe "uploads accessor" do
    test "FormInfo.uploads/1 returns list" do
      uploads = FormInfo.uploads(FormPost)
      assert is_list(uploads)
    end

    test "FormInfo.uploads/1 returns empty list for MinimalForm" do
      assert FormInfo.uploads(MinimalForm) == []
    end
  end
end
