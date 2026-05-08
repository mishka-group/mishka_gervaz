defmodule MishkaGervaz.Form.Types.Field.ToggleTest do
  @moduledoc "Direct tests for the `:toggle` field type (boolean rendered as switch)."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Toggle

  test "render/2" do
    assert Toggle.render(%{}, %{}) == %{}
  end

  test "validate/2 passes through" do
    assert Toggle.validate(true, %{}) == {:ok, true}
    assert Toggle.validate(false, %{}) == {:ok, false}
  end

  test "parse_params/2 passes through" do
    assert Toggle.parse_params("true", %{}) == "true"
  end

  test "sanitize/2 passes through" do
    assert Toggle.sanitize(true, %{}) == true
  end

  test "default_ui/0" do
    assert Toggle.default_ui() == %{type: :toggle}
  end
end
