defmodule MishkaGervaz.Form.Types.Field.DateTimeTest do
  @moduledoc "Direct tests for the `:datetime` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.DateTime, as: DateTimeField

  describe "validate/2" do
    test "accepts naive ISO-8601 datetime" do
      assert DateTimeField.validate("2025-01-15T10:30:00", %{}) ==
               {:ok, "2025-01-15T10:30:00"}
    end

    test "accepts zoned ISO-8601 datetime" do
      assert DateTimeField.validate("2025-01-15T10:30:00Z", %{}) ==
               {:ok, "2025-01-15T10:30:00Z"}

      assert DateTimeField.validate("2025-01-15T10:30:00+02:00", %{}) ==
               {:ok, "2025-01-15T10:30:00+02:00"}
    end

    test "rejects invalid strings" do
      assert DateTimeField.validate("not-a-datetime", %{}) ==
               {:error, "must be a valid date and time"}

      assert DateTimeField.validate("2025-13-01T10:00:00", %{}) ==
               {:error, "must be a valid date and time"}
    end

    test "passes through empty / nil / non-binary" do
      assert DateTimeField.validate("", %{}) == {:ok, ""}
      assert DateTimeField.validate(nil, %{}) == {:ok, nil}
      assert DateTimeField.validate(:atom, %{}) == {:ok, :atom}
    end
  end

  describe "sanitize/2" do
    test "trims binaries" do
      assert DateTimeField.sanitize("  2025-01-15T10:30:00Z  ", %{}) ==
               "2025-01-15T10:30:00Z"
    end

    test "passes non-binaries through" do
      assert DateTimeField.sanitize(nil, %{}) == nil
    end
  end

  test "render/2 + parse_params/2 pass through" do
    assert DateTimeField.render(%{}, %{}) == %{}
    assert DateTimeField.parse_params("v", %{}) == "v"
  end

  test "default_ui/0" do
    assert DateTimeField.default_ui() == %{type: :datetime}
  end
end
