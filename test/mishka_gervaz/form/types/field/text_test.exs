defmodule MishkaGervaz.Form.Types.Field.TextTest do
  @moduledoc "Direct tests for the `:text` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Text

  doctest MishkaGervaz.Form.Types.Field.Text, only: [plain_text: 1, within_length: 2]

  describe "behaviour callbacks" do
    test "render/2 returns assigns unchanged" do
      assert Text.render(%{a: 1}, %{}) == %{a: 1}
    end

    test "validate/2 takes plain text, a bare < or > included" do
      assert Text.validate("hello", %{}) == {:ok, "hello"}
      assert Text.validate("a < b > c", %{}) == {:ok, "a < b > c"}
      assert Text.validate(nil, %{}) == {:ok, nil}
      assert Text.validate("", %{}) == {:ok, ""}
    end

    test "validate/2 refuses a value longer than the field's max_length, naming the limit" do
      assert Text.validate("Ann", %{max_length: 3}) == {:ok, "Ann"}

      assert Text.validate("Anna", %{max_length: 3}) ==
               {:error, {"must be %{count} characters or fewer", [count: 3]}}

      assert Text.validate("Anna", %{max_length: nil}) == {:ok, "Anna"}
    end

    test "validate/2 counts characters, not bytes" do
      assert Text.validate("نامِ", %{max_length: 4}) == {:ok, "نامِ"}
    end

    test "validate/2 refuses a value that holds an HTML tag, in words" do
      for value <- ["<b>hello</b>", "<script>alert(1)</script>", "Ann <img src=x>"] do
        assert Text.validate(value, %{}) == {:error, "must be plain text, without HTML tags"}
      end
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
    test "keeps HTML tags as typed, for validate/2 to refuse" do
      assert Text.sanitize("<b>hello</b>", %{}) == "<b>hello</b>"
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
