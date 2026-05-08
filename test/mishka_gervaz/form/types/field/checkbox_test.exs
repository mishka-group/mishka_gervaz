defmodule MishkaGervaz.Form.Types.Field.CheckboxTest do
  @moduledoc "Direct tests for the `:checkbox` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Checkbox

  test "render/2" do
    assert Checkbox.render(%{}, %{}) == %{}
  end

  test "validate/2" do
    assert Checkbox.validate(true, %{}) == {:ok, true}
    assert Checkbox.validate(false, %{}) == {:ok, false}
    assert Checkbox.validate("true", %{}) == {:ok, "true"}
  end

  test "parse_params/2 passes through" do
    assert Checkbox.parse_params("true", %{}) == "true"
    assert Checkbox.parse_params(true, %{}) == true
  end

  test "sanitize/2 passes through" do
    assert Checkbox.sanitize(true, %{}) == true
    assert Checkbox.sanitize("false", %{}) == "false"
  end

  test "default_ui/0" do
    assert Checkbox.default_ui() == %{type: :checkbox}
  end
end
