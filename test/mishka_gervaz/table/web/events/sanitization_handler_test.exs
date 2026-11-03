defmodule MishkaGervaz.Table.Web.Events.SanitizationHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Table.Web.Events.SanitizationHandler.Default`.

  Covers the three callbacks (`sanitize/1`, `sanitize_column/1`, `sanitize_page/1`)
  and the override pattern via `use`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Events.SanitizationHandler.Default, as: Sanitizer

  describe "sanitize/1" do
    test "strips HTML tags from binaries" do
      assert Sanitizer.sanitize("<b>hi</b>") == "hi"
      assert Sanitizer.sanitize("<script>alert('x')</script>") == "alert('x')"
    end

    test "passes non-binaries through unchanged" do
      assert Sanitizer.sanitize(:atom) == :atom
      assert Sanitizer.sanitize(123) == 123
      assert Sanitizer.sanitize(nil) == nil
    end

    test "preserves plain strings" do
      assert Sanitizer.sanitize("plain text") == "plain text"
    end

    test "keeps & and quotes as typed, escaping nothing" do
      assert Sanitizer.sanitize(~s(Tom & Jerry's "cat" <b>x</b>)) == ~s(Tom & Jerry's "cat" x)
    end

    test "takes out a tag hidden inside a tag" do
      assert Sanitizer.sanitize("<scr<script>ipt>alert(1)</script>") =~ "alert(1)"
      refute Sanitizer.sanitize("<scr<script>ipt>alert(1)</script>") =~ "<"
    end
  end

  describe "sanitize_column/1" do
    test "resolves a known existing atom" do
      # :title exists because the test suite already references it
      _ = :title
      assert Sanitizer.sanitize_column("title") == :title
    end

    test "raises for an atom that does not exist" do
      assert_raise ArgumentError, fn ->
        Sanitizer.sanitize_column("nope_does_not_exist_xyzzy")
      end
    end
  end

  describe "sanitize_page/1" do
    test "parses numeric strings" do
      assert Sanitizer.sanitize_page("3") == 3
      assert Sanitizer.sanitize_page("10") == 10
    end

    test "passes positive integers through" do
      assert Sanitizer.sanitize_page(7) == 7
    end

    test "reads the number inside tags" do
      assert Sanitizer.sanitize_page("<b>4</b>") == 4
    end

    test "is nil for anything that is not a positive whole number" do
      for page <- ["two", "1.5", "", " 2", "2abc", "0", "-3", 0, -3, 1.5, nil, :weird, ["2"]] do
        assert {page, Sanitizer.sanitize_page(page)} == {page, nil}
      end
    end

    test "keeps a page of any size" do
      assert Sanitizer.sanitize_page("99999999999999999999999") == 99_999_999_999_999_999_999_999
    end
  end

  describe "override pattern" do
    test "user can override sanitize/1 via use" do
      defmodule TableSanitizationOverride do
        use MishkaGervaz.Table.Web.Events.SanitizationHandler

        def sanitize(value) when is_binary(value), do: String.upcase(super(value))
        def sanitize(value), do: super(value)
      end

      assert TableSanitizationOverride.sanitize("<b>hi</b>") == "HI"
    end
  end
end
