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

    test "accepts the minutes a browser's datetime-local input sends, completing them" do
      assert DateTimeField.validate("2024-09-09T22:45", %{}) == {:ok, "2024-09-09T22:45:00"}
      assert DateTimeField.validate("2024-09-09 22:45", %{}) == {:ok, "2024-09-09 22:45:00"}
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

  describe "validate/2 with min and max" do
    test "a min time counts from the start of its minute, and a Date max takes its whole day" do
      config = %{min: ~N[2024-01-10 08:30:45], max: ~D[2024-01-20]}

      assert DateTimeField.validate("2024-01-10T08:30", config) == {:ok, "2024-01-10T08:30:00"}
      assert DateTimeField.validate("2024-01-20T23:59:00", config) == {:ok, "2024-01-20T23:59:00"}
      assert DateTimeField.validate("2024-01-10T08:29:00", config) == {:error, "is too early"}
      assert DateTimeField.validate("2024-01-21T00:00:00Z", config) == {:error, "is too late"}

      assert DateTimeField.validate(~U[2024-01-09 10:00:00Z], config) ==
               {:error, "is too early"}
    end

    test "a function is read each time" do
      config = %{min: fn -> DateTime.utc_now() end}

      assert {:error, _} = DateTimeField.validate("2020-01-01T10:00", config)
      assert {:ok, _} = DateTimeField.validate("2999-01-01T10:00", config)
    end
  end

  describe "bound/3 and clamp/3" do
    test "give the bound as the input's attribute, and move a value outside it to its edge" do
      field = %{type: :datetime, min: ~N[2024-01-10 08:30:45], max: ~D[2024-01-20]}

      assert DateTimeField.bound(field, :min, :datetime) == "2024-01-10T08:30:00"
      assert DateTimeField.bound(field, :max, :date) == "2024-01-20"
      assert DateTimeField.bound(%{}, :min, :date) == nil

      assert DateTimeField.clamp(field, ~D[2024-01-10], {0, 0}) == "2024-01-10T08:30:00"
      assert DateTimeField.clamp(field, ~D[2024-01-12], {9, 15}) == "2024-01-12T09:15:00"
      assert DateTimeField.clamp(field, ~D[2024-02-01], {9, 15}) == "2024-01-20T23:59:00"
    end
  end

  describe "sanitize/2" do
    test "completes a datetime-local value with its seconds" do
      assert DateTimeField.sanitize(" 2024-09-09T22:45 ", %{}) == "2024-09-09T22:45:00"
      assert DateTimeField.parse_params("2024-09-09T22:45", %{}) == "2024-09-09T22:45:00"
    end

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
