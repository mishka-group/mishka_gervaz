defmodule MishkaGervaz.Form.Types.Field.TextareaTest do
  @moduledoc "Direct tests for the `:textarea` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Textarea

  test "render/2 returns assigns unchanged" do
    assert Textarea.render(%{x: 1}, %{}) == %{x: 1}
  end

  test "parse_params/2 passes through" do
    assert Textarea.parse_params("x", %{}) == "x"
  end

  test "default_ui/0" do
    assert Textarea.default_ui() == %{type: :textarea}
  end

  test "validate/2 keeps markup and refuses a value longer than the field's max_length" do
    assert Textarea.validate("<p>Hi</p>", %{max_length: 9}) == {:ok, "<p>Hi</p>"}

    assert Textarea.validate("<p>Hi!</p>", %{max_length: 9}) ==
             {:error, {"must be %{count} characters or fewer", [count: 9]}}
  end
end
