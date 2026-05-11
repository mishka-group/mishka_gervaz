defmodule MishkaGervaz.Form.Types.Field.JsonTest do
  @moduledoc "Direct tests for the `:json` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Json

  describe "validate/2 — map / list inputs" do
    test "accepts maps when ash_type is :map" do
      assert Json.validate(%{"a" => 1}, %{ash_type: :map}) == {:ok, %{"a" => 1}}
      assert Json.validate(%{"a" => 1}, %{ash_type: Ash.Type.Map}) == {:ok, %{"a" => 1}}
    end

    test "accepts lists when ash_type is {:array, _}" do
      assert Json.validate([1, 2, 3], %{ash_type: {:array, :string}}) == {:ok, [1, 2, 3]}
    end

    test "rejects list when ash_type expects map" do
      assert Json.validate([1, 2], %{ash_type: :map}) == {:error, "must be a JSON object"}
    end

    test "rejects map when ash_type expects array" do
      assert Json.validate(%{}, %{ash_type: {:array, :string}}) ==
               {:error, "must be a JSON array"}
    end

    test "no ash_type constraint passes through" do
      assert Json.validate(%{"a" => 1}, %{}) == {:ok, %{"a" => 1}}
      assert Json.validate([1], %{}) == {:ok, [1]}
    end
  end

  describe "validate/2 — string inputs" do
    test "accepts valid JSON object string" do
      assert Json.validate(~s({"a": 1}), %{}) == {:ok, ~s({"a": 1})}
    end

    test "accepts valid JSON array string" do
      assert Json.validate(~s([1, 2]), %{}) == {:ok, ~s([1, 2])}
    end

    test "rejects invalid JSON" do
      assert Json.validate("not json", %{}) == {:error, "must be valid JSON"}
      assert Json.validate(~s({"oops"), %{}) == {:error, "must be valid JSON"}
    end

    test "decoded string respects ash_type constraint" do
      assert Json.validate(~s([1, 2]), %{ash_type: :map}) == {:error, "must be a JSON object"}

      assert Json.validate(~s({"a": 1}), %{ash_type: {:array, :string}}) ==
               {:error, "must be a JSON array"}
    end
  end

  describe "validate/2 — empty / passthrough" do
    test "empty string passes through" do
      assert Json.validate("", %{}) == {:ok, ""}
    end

    test "nil and other shapes pass through" do
      assert Json.validate(nil, %{}) == {:ok, nil}
      assert Json.validate(42, %{}) == {:ok, 42}
    end
  end

  describe "parse_params/2" do
    test "decodes valid JSON binary into map" do
      assert Json.parse_params(~s({"a": 1}), %{}) == %{"a" => 1}
    end

    test "decodes valid JSON binary into list" do
      assert Json.parse_params(~s([1, 2]), %{}) == [1, 2]
    end

    test "passes invalid JSON binary through unchanged" do
      assert Json.parse_params("not json", %{}) == "not json"
    end

    test "passes empty string and non-binary through" do
      assert Json.parse_params("", %{}) == ""
      assert Json.parse_params(%{"already" => "map"}, %{}) == %{"already" => "map"}
      assert Json.parse_params(nil, %{}) == nil
    end
  end

  test "render/2 + sanitize/2 pass through" do
    assert Json.render(%{}, %{}) == %{}
    assert Json.sanitize("v", %{}) == "v"
  end

  test "default_ui/0" do
    assert Json.default_ui() == %{type: :json}
  end
end
