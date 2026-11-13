defmodule MishkaGervaz.Form.Types.Field.DateTest do
  @moduledoc "Direct tests for the `:date` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Date, as: DateField

  describe "validate/2" do
    test "accepts valid ISO-8601 date strings" do
      assert DateField.validate("2025-01-15", %{}) == {:ok, "2025-01-15"}
      assert DateField.validate("1999-12-31", %{}) == {:ok, "1999-12-31"}
    end

    test "rejects invalid date strings" do
      assert DateField.validate("not-a-date", %{}) == {:error, "must be a valid date"}
      assert DateField.validate("2025-13-01", %{}) == {:error, "must be a valid date"}
      assert DateField.validate("2025-02-30", %{}) == {:error, "must be a valid date"}
    end

    test "passes through nil and empty string" do
      assert DateField.validate("", %{}) == {:ok, ""}
      assert DateField.validate(nil, %{}) == {:ok, nil}
    end

    test "passes through non-binary values" do
      assert DateField.validate(:not_a_string, %{}) == {:ok, :not_a_string}
    end
  end

  describe "validate/2 with min and max" do
    test "takes the days from min to max, and refuses the others" do
      config = %{min: ~D[2024-01-10], max: fn -> ~U[2024-01-20 08:00:00Z] end}

      assert DateField.validate("2024-01-10", config) == {:ok, "2024-01-10"}
      assert DateField.validate("2024-01-20", config) == {:ok, "2024-01-20"}
      assert DateField.validate(~D[2024-01-15], config) == {:ok, ~D[2024-01-15]}
      assert DateField.validate("2024-01-09", config) == {:error, "is too early"}
      assert DateField.validate("2024-01-21", config) == {:error, "is too late"}
    end
  end

  describe "sanitize/2" do
    test "trims binary values" do
      assert DateField.sanitize("  2025-01-15  ", %{}) == "2025-01-15"
    end

    test "passes non-binaries through" do
      assert DateField.sanitize(nil, %{}) == nil
      assert DateField.sanitize(:atom, %{}) == :atom
    end
  end

  test "render/2 + parse_params/2 pass through" do
    assert DateField.render(%{}, %{}) == %{}
    assert DateField.parse_params("v", %{}) == "v"
  end

  test "default_ui/0" do
    assert DateField.default_ui() == %{type: :date}
  end
end
