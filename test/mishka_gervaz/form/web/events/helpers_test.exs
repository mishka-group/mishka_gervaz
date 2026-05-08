defmodule MishkaGervaz.Form.Web.Events.HelpersTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Form.Web.Events.Helpers` — covers the
  helpers moved out of the previous `Events.Builder` module plus the
  `defp` helpers extracted from `SubmitHandler` and `SanitizationHandler`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.Helpers

  describe "parse_typed_params/2" do
    test "passes through when fields list is empty" do
      assert Helpers.parse_typed_params([], %{"a" => 1}) == %{"a" => 1}
    end

    test "passes through when no field has :type_module" do
      fields = [%{name: :title}]
      assert Helpers.parse_typed_params(fields, %{"title" => "T"}) == %{"title" => "T"}
    end

    test "applies type_module.parse_params/2 when present" do
      defmodule TestParseType do
        def parse_params(value, _config), do: String.upcase(value)
      end

      fields = [%{name: :title, type_module: TestParseType}]
      assert Helpers.parse_typed_params(fields, %{"title" => "hi"}) == %{"title" => "HI"}
    end

    test "skips fields not in params" do
      defmodule TestSkipType do
        def parse_params(_value, _config), do: :should_not_run
      end

      fields = [%{name: :missing, type_module: TestSkipType}]
      assert Helpers.parse_typed_params(fields, %{"other" => 1}) == %{"other" => 1}
    end

    test "fallthrough for non-list fields or non-map params" do
      assert Helpers.parse_typed_params(:atom, %{"a" => 1}) == %{"a" => 1}
      assert Helpers.parse_typed_params([], "string") == "string"
    end
  end

  describe "sanitize_typed_params/2" do
    test "applies type_module.sanitize/2 when present" do
      defmodule TestSanitizeType do
        def sanitize(value, _config), do: String.trim(value)
      end

      fields = [%{name: :title, type_module: TestSanitizeType}]

      assert Helpers.sanitize_typed_params(fields, %{"title" => "  hi  "}) ==
               %{"title" => "hi"}
    end

    test "no-op when type_module missing" do
      fields = [%{name: :title}]

      assert Helpers.sanitize_typed_params(fields, %{"title" => "  hi  "}) ==
               %{"title" => "  hi  "}
    end
  end

  describe "sanitize_list_item/2 (formerly defp in SanitizationHandler)" do
    test "string: strips HTML and trims" do
      assert Helpers.sanitize_list_item(" <b>hi</b> ", &Helpers.sanitize_string/1) == "hi"
    end

    test "map: recursively sanitizes via passed sanitize_params fn" do
      sanitize_params = fn m -> Map.new(m, fn {k, v} -> {k, Helpers.sanitize_string(v)} end) end

      assert Helpers.sanitize_list_item(%{"a" => "<i>x</i>"}, sanitize_params) ==
               %{"a" => "x"}
    end

    test "any other value passes through" do
      assert Helpers.sanitize_list_item(:atom, & &1) == :atom
      assert Helpers.sanitize_list_item(123, & &1) == 123
    end
  end

  describe "sanitize_string/1" do
    test "strips HTML tags" do
      assert Helpers.sanitize_string("<b>x</b>") == "x"
    end

    test "trims whitespace" do
      assert Helpers.sanitize_string("  x  ") == "x"
    end

    test "passes non-binary through" do
      assert Helpers.sanitize_string(:atom) == :atom
      assert Helpers.sanitize_string(42) == 42
    end
  end

  describe "merge_uploaded_files/4 (formerly defp in SubmitHandler)" do
    test "no-op when uploaded_files is empty" do
      assert Helpers.merge_uploaded_files(:sock, %{"a" => 1}, %{name: :avatar}, []) ==
               {:sock, %{"a" => 1}}
    end

    test "writes uploads under upload_config[:field] when set" do
      uploads = [%{path: "/tmp/x.png"}]

      assert Helpers.merge_uploaded_files(:sock, %{}, %{name: :cover, field: :photo_url}, uploads) ==
               {:sock, %{"photo_url" => uploads}}
    end

    test "falls back to upload_config.name when :field missing" do
      uploads = [%{path: "/tmp/y.png"}]

      assert Helpers.merge_uploaded_files(:sock, %{}, %{name: :avatar}, uploads) ==
               {:sock, %{"avatar" => uploads}}
    end
  end
end
