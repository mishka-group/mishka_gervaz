defmodule MishkaGervaz.Form.Web.DefaultsTest do
  @moduledoc """
  Tests for the defaults assign feature.

  The defaults assign allows parent LiveViews to pass default field values
  to the form component, which are merged into form params on create submission.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State
  import MishkaGervaz.Test.FormWebHelpers

  describe "defaults in state" do
    test "defaults is nil by default" do
      state = build_state()
      assert state.defaults == nil
    end

    test "defaults can be set via build_state" do
      state = build_state(defaults: %{workspace_id: "ws-123"})
      assert state.defaults == %{workspace_id: "ws-123"}
    end

    test "defaults can be updated via State.update" do
      state = build_state()
      updated = State.update(state, defaults: %{site_id: "site-1"})
      assert updated.defaults == %{site_id: "site-1"}
    end

    test "defaults preserves existing state fields on update" do
      state = build_state(defaults: %{workspace_id: "ws-123"}, mode: :create)
      updated = State.update(state, mode: :update)
      assert updated.defaults == %{workspace_id: "ws-123"}
      assert updated.mode == :update
    end
  end

  describe "merge_defaults logic" do
    test "merges defaults into params on create mode" do
      defaults = %{workspace_id: "ws-123", site_id: "site-1"}
      params = %{"title" => "My Post", "status" => "draft"}

      result = merge_defaults(:create, defaults, params)

      assert result["workspace_id"] == "ws-123"
      assert result["site_id"] == "site-1"
      assert result["title"] == "My Post"
    end

    test "does not merge defaults on update mode" do
      defaults = %{workspace_id: "ws-123"}
      params = %{"title" => "My Post"}

      result = merge_defaults(:update, defaults, params)

      refute Map.has_key?(result, "workspace_id")
    end

    test "does not overwrite existing non-empty params" do
      defaults = %{status: "draft"}
      params = %{"status" => "published"}

      result = merge_defaults(:create, defaults, params)

      assert result["status"] == "published"
    end

    test "overwrites empty string params" do
      defaults = %{workspace_id: "ws-123"}
      params = %{"workspace_id" => ""}

      result = merge_defaults(:create, defaults, params)

      assert result["workspace_id"] == "ws-123"
    end

    test "overwrites nil params" do
      defaults = %{workspace_id: "ws-123"}
      params = %{"workspace_id" => nil}

      result = merge_defaults(:create, defaults, params)

      assert result["workspace_id"] == "ws-123"
    end

    test "handles nil defaults" do
      params = %{"title" => "My Post"}
      result = merge_defaults(:create, nil, params)
      assert result == params
    end

    test "handles empty defaults map" do
      params = %{"title" => "My Post"}
      result = merge_defaults(:create, %{}, params)
      assert result == params
    end

    test "converts atom keys to string keys" do
      defaults = %{workspace_id: "ws-123"}
      params = %{}

      result = merge_defaults(:create, defaults, params)

      assert result["workspace_id"] == "ws-123"
      refute Map.has_key?(result, :workspace_id)
    end

    test "handles multiple defaults" do
      defaults = %{
        workspace_id: "ws-123",
        site_id: "site-1",
        language: "en"
      }

      params = %{"title" => "Post", "language" => "fa"}

      result = merge_defaults(:create, defaults, params)

      assert result["workspace_id"] == "ws-123"
      assert result["site_id"] == "site-1"
      assert result["language"] == "fa"
    end
  end

  # Mirrors the merge_defaults logic from SubmitHandler
  defp merge_defaults(:create, defaults, params)
       when is_map(defaults) and defaults != %{} do
    Enum.reduce(defaults, params, fn {key, value}, acc ->
      str_key = to_string(key)

      if Map.has_key?(acc, str_key) and acc[str_key] not in [nil, ""] do
        acc
      else
        Map.put(acc, str_key, value)
      end
    end)
  end

  defp merge_defaults(_mode, _defaults, params), do: params
end
