defmodule MishkaGervaz.Form.Types.Field.TextTest do
  @moduledoc "Direct tests for the `:text` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Text

  describe "behaviour callbacks" do
    test "render/2 returns assigns unchanged" do
      assert Text.render(%{a: 1}, %{}) == %{a: 1}
    end

    test "validate/2 always returns {:ok, value}" do
      assert Text.validate("hello", %{}) == {:ok, "hello"}
      assert Text.validate(nil, %{}) == {:ok, nil}
      assert Text.validate("", %{}) == {:ok, ""}
    end

    test "parse_params/2 passes through" do
      assert Text.parse_params("x", %{}) == "x"
      assert Text.parse_params(123, %{}) == 123
    end

    test "default_ui/0 returns %{type: :text}" do
      assert Text.default_ui() == %{type: :text}
    end
  end

  describe "sanitize/2" do
    test "strips HTML tags from binaries" do
      assert Text.sanitize("<b>hello</b>", %{}) == "hello"
      assert Text.sanitize("<script>alert('x')</script>", %{}) == "alert('x')"
    end

    test "trims whitespace" do
      assert Text.sanitize("  spaced  ", %{}) == "spaced"
    end

    test "passes non-binaries through" do
      assert Text.sanitize(:atom, %{}) == :atom
      assert Text.sanitize(123, %{}) == 123
      assert Text.sanitize(nil, %{}) == nil
    end
  end
end
