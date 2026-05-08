defmodule MishkaGervaz.Form.Types.Field.RangeTest do
  @moduledoc "Direct tests for the `:range` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Range, as: RangeField

  describe "validate/2" do
    test "accepts integer / float values directly" do
      assert RangeField.validate(50, %{}) == {:ok, 50}
      assert RangeField.validate(3.14, %{}) == {:ok, 3.14}
      assert RangeField.validate(0, %{}) == {:ok, 0}
    end

    test "accepts numeric strings" do
      assert RangeField.validate("50", %{}) == {:ok, "50"}
      assert RangeField.validate("3.14", %{}) == {:ok, "3.14"}
      assert RangeField.validate("-5", %{}) == {:ok, "-5"}
    end

    test "rejects non-numeric strings" do
      assert RangeField.validate("abc", %{}) == {:error, "must be a number"}
      assert RangeField.validate("not-a-number", %{}) == {:error, "must be a number"}
    end

    test "passes through empty / nil / non-binary non-numeric" do
      assert RangeField.validate("", %{}) == {:ok, ""}
      assert RangeField.validate(nil, %{}) == {:ok, nil}
      assert RangeField.validate(:atom, %{}) == {:ok, :atom}
    end
  end

  test "render/2, parse_params/2, sanitize/2 pass through" do
    assert RangeField.render(%{}, %{}) == %{}
    assert RangeField.parse_params(50, %{}) == 50
    assert RangeField.sanitize(50, %{}) == 50
  end

  test "default_ui/0" do
    assert RangeField.default_ui() == %{type: :range}
  end
end
