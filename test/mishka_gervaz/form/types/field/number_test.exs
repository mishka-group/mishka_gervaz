defmodule MishkaGervaz.Form.Types.Field.NumberTest do
  @moduledoc "Direct tests for the `:number` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Number, as: NumberField

  describe "validate/2 — numeric values" do
    test "accepts any number when ash_type is unrestricted" do
      assert NumberField.validate(42, %{}) == {:ok, 42}
      assert NumberField.validate(3.14, %{}) == {:ok, 3.14}
    end

    test "rejects float when ash_type forces integer" do
      assert NumberField.validate(3.14, %{ash_type: :integer}) ==
               {:error, "must be a whole number"}

      assert NumberField.validate(3.14, %{ash_type: Ash.Type.Integer}) ==
               {:error, "must be a whole number"}
    end

    test "accepts integer when ash_type forces integer" do
      assert NumberField.validate(42, %{ash_type: :integer}) == {:ok, 42}
      assert NumberField.validate(42, %{ash_type: Ash.Type.Integer}) == {:ok, 42}
    end
  end

  describe "validate/2 — string values" do
    test "accepts integer strings for any ash_type" do
      assert NumberField.validate("42", %{}) == {:ok, "42"}
      assert NumberField.validate("42", %{ash_type: :integer}) == {:ok, "42"}
    end

    test "rejects float strings when ash_type is integer" do
      assert NumberField.validate("3.14", %{ash_type: :integer}) ==
               {:error, "must be a whole number"}
    end

    test "accepts float strings when ash_type is unrestricted" do
      assert NumberField.validate("3.14", %{}) == {:ok, "3.14"}
    end

    test "rejects garbage strings" do
      assert NumberField.validate("abc", %{}) == {:error, "must be a number"}
    end
  end

  describe "validate/2 — passthrough" do
    test "empty / nil / non-binary non-number" do
      assert NumberField.validate("", %{}) == {:ok, ""}
      assert NumberField.validate(nil, %{}) == {:ok, nil}
      assert NumberField.validate(:atom, %{}) == {:ok, :atom}
    end
  end

  describe "sanitize/2" do
    test "strips HTML and trims binaries" do
      assert NumberField.sanitize(" <b>42</b> ", %{}) == "42"
    end

    test "passes non-binaries through" do
      assert NumberField.sanitize(42, %{}) == 42
    end
  end

  test "render/2 + parse_params/2 pass through" do
    assert NumberField.render(%{}, %{}) == %{}
    assert NumberField.parse_params(42, %{}) == 42
  end

  test "default_ui/0" do
    assert NumberField.default_ui() == %{type: :number}
  end
end
