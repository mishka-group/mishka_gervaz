defmodule MishkaGervaz.Form.Types.Field.SelectTest do
  @moduledoc "Direct tests for the `:select` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Select

  test "render/2" do
    assert Select.render(%{}, %{}) == %{}
  end

  test "validate/2 passes through" do
    assert Select.validate("draft", %{}) == {:ok, "draft"}
    assert Select.validate(nil, %{}) == {:ok, nil}
  end

  test "parse_params/2 passes through" do
    assert Select.parse_params("v", %{}) == "v"
  end

  test "sanitize/2 trims binary values" do
    assert Select.sanitize("  draft  ", %{}) == "draft"
  end

  test "sanitize/2 passes non-binaries" do
    assert Select.sanitize(:atom, %{}) == :atom
    assert Select.sanitize(123, %{}) == 123
  end

  test "default_ui/0" do
    assert Select.default_ui() == %{type: :select}
  end

  describe "prompt/1" do
    test "none for a required field" do
      assert Select.prompt(%{required: true}) == nil
    end

    test "none for a field with a default" do
      assert Select.prompt(%{required: false, default: :draft}) == nil
    end

    test "a neutral \"Select...\" for an optional field, never \"All\"" do
      assert Select.prompt(%{required: false}) == "Select..."
      assert Select.prompt(%{}) == "Select..."
    end

    test "the ui placeholder wins, string or function, required or not" do
      assert Select.prompt(%{required: true, ui: %{placeholder: "Pick one"}}) == "Pick one"
      assert Select.prompt(%{ui: %{placeholder: fn -> "Choose" end}}) == "Choose"
    end

    test "a ui without a placeholder falls back to the field rules" do
      assert Select.prompt(%{required: true, ui: %{placeholder: nil}}) == nil
      assert Select.prompt(%{ui: nil}) == "Select..."
    end
  end
end
