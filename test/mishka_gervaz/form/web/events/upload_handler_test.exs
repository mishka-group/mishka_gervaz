defmodule MishkaGervaz.Form.Web.Events.UploadHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.UploadHandler.Default`.

  Covers the public helper `resolve_upload_name/2`. The
  `handle_upload/3` and `cancel_upload/4` callbacks call into
  `Phoenix.LiveView` (consume_uploaded_entries / cancel_upload) and need
  a real socket — exercised via `events_test.exs`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.UploadHandler

  describe "resolve_upload_name/2" do
    test "namespaces using state.static.id" do
      state = %{static: %{id: "post-form"}}
      assert UploadHandler.resolve_upload_name(state, :avatar) == :avatar_post_form
    end

    test "passes upload_key through when state has no :id" do
      assert UploadHandler.resolve_upload_name(%{}, :avatar) == :avatar
      assert UploadHandler.resolve_upload_name(nil, :cover) == :cover
    end

    test "sanitises non-alphanumeric chars in id" do
      state = %{static: %{id: "post-form/123"}}
      assert UploadHandler.resolve_upload_name(state, :avatar) == :avatar_post_form_123
    end
  end
end
