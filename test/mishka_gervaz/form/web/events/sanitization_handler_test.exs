defmodule MishkaGervaz.Form.Web.Events.SanitizationHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.SanitizationHandler.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.SanitizationHandler.Default, as: Sanitizer

  describe "sanitize/1" do
    test "strips HTML tags from binaries" do
      assert Sanitizer.sanitize("<b>hi</b>") == "hi"
      assert Sanitizer.sanitize("<script>alert('x')</script>") == "alert('x')"
    end

    test "trims whitespace" do
      assert Sanitizer.sanitize("  spaced  ") == "spaced"
    end

    test "passes non-binaries through" do
      assert Sanitizer.sanitize(:atom) == :atom
      assert Sanitizer.sanitize(123) == 123
      assert Sanitizer.sanitize(nil) == nil
    end
  end

  describe "sanitize_params/1" do
    test "sanitizes top-level binary values" do
      assert Sanitizer.sanitize_params(%{"name" => "  <b>x</b>  "}) == %{"name" => "x"}
    end

    test "passes non-binary values through" do
      assert Sanitizer.sanitize_params(%{"n" => 42, "f" => false, "a" => :sym}) ==
               %{"n" => 42, "f" => false, "a" => :sym}
    end

    test "recursively sanitizes nested maps" do
      assert Sanitizer.sanitize_params(%{"outer" => %{"inner" => " <i>v</i> "}}) ==
               %{"outer" => %{"inner" => "v"}}
    end

    test "sanitizes binary items inside lists" do
      assert Sanitizer.sanitize_params(%{"tags" => [" <b>a</b> ", "b"]}) ==
               %{"tags" => ["a", "b"]}
    end

    test "recursively sanitizes maps inside lists" do
      assert Sanitizer.sanitize_params(%{"items" => [%{"k" => " <i>v</i> "}]}) ==
               %{"items" => [%{"k" => "v"}]}
    end
  end

  describe "override pattern" do
    test "user override of sanitize/1 cascades through sanitize_params/1" do
      defmodule TestSanitizationOverride do
        use MishkaGervaz.Form.Web.Events.SanitizationHandler

        def sanitize(value) when is_binary(value), do: String.upcase(super(value))
        def sanitize(value), do: super(value)
      end

      assert TestSanitizationOverride.sanitize_params(%{"a" => " <b>hi</b> "}) ==
               %{"a" => "HI"}
    end
  end
end
