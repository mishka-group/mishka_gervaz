defmodule MishkaGervaz.ErrorsTest do
  @moduledoc """
  Tests for `MishkaGervaz.Errors` — flash formatting, error message extraction,
  and the live Splode error classes.

  Only covers paths that are actually exercised in the lib (`Action.Failed`,
  `Data.LoadFailed`, `Ash.Error.Invalid`, generic shapes). Unused error
  structs are not exercised here.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Errors
  alias MishkaGervaz.Errors.Action.Failed
  alias MishkaGervaz.Errors.Data.LoadFailed

  describe "format_flash_message/1 — Action.Failed" do
    test "humanizes a snake_case action and includes the reason" do
      err = Failed.exception(action: :permanent_destroy, reason: "forbidden")
      assert Errors.format_flash_message(err) == "Permanent destroy failed: forbidden"
    end

    test "humanizes a single-word atom action" do
      err = Failed.exception(action: :archive, reason: "denied")
      assert Errors.format_flash_message(err) == "Archive failed: denied"
    end

    test "binary action name is capitalized" do
      err = Failed.exception(action: "archive", reason: "denied")
      assert Errors.format_flash_message(err) == "Archive failed: denied"
    end

    test "non-atom non-binary action falls back to generic 'Action'" do
      err = Failed.exception(action: nil, reason: "boom")
      assert Errors.format_flash_message(err) == "Action failed: boom"
    end

    test "reason as a bulk_action_failed tuple with one error" do
      reason = {:bulk_action_failed, :stream, [%{message: "single"}]}
      err = Failed.exception(action: :delete, reason: reason)
      assert Errors.format_flash_message(err) == "Delete failed: single"
    end

    test "reason as a bulk_action_failed tuple with several errors" do
      reason = {:bulk_action_failed, :stream, [%{message: "a"}, %{message: "b"}]}
      err = Failed.exception(action: :delete, reason: reason)
      assert Errors.format_flash_message(err) == "Delete failed: 2 errors occurred"
    end

    test "reason as Ash.Error.Invalid takes up to 3 errors" do
      reason = %Ash.Error.Invalid{
        errors: [
          %{message: "a"},
          %{message: "b"},
          %{message: "c"},
          %{message: "d"}
        ]
      }

      err = Failed.exception(action: :update, reason: reason)
      assert Errors.format_flash_message(err) == "Update failed: a, b, c"
    end

    test "non-binary reason is inspected" do
      err = Failed.exception(action: :update, reason: {:tuple, "reason"})
      assert Errors.format_flash_message(err) == ~s(Update failed: {:tuple, "reason"})
    end
  end

  describe "format_flash_message/1 — Data.LoadFailed" do
    test "binary reason renders as-is" do
      err = LoadFailed.exception(resource: SomeResource, reason: "timeout")
      assert Errors.format_flash_message(err) == "Failed to load data: timeout"
    end

    test "non-binary reason is inspected" do
      err = LoadFailed.exception(resource: SomeResource, reason: :timeout)
      assert Errors.format_flash_message(err) == "Failed to load data: :timeout"
    end
  end

  describe "format_flash_message/1 — Ash.Error.Invalid" do
    test "prefixes with 'Validation failed:' and joins up to 3 errors" do
      err = %Ash.Error.Invalid{
        errors: [%{message: "a"}, %{message: "b"}, %{message: "c"}, %{message: "d"}]
      }

      assert Errors.format_flash_message(err) == "Validation failed: a, b, c"
    end

    test "single error" do
      err = %Ash.Error.Invalid{errors: [%{message: "only"}]}
      assert Errors.format_flash_message(err) == "Validation failed: only"
    end

    test "field-shaped error is rendered as 'field: msg'" do
      err = %Ash.Error.Invalid{errors: [%{field: :email, message: "is invalid"}]}
      assert Errors.format_flash_message(err) == "Validation failed: email: is invalid"
    end
  end

  describe "format_flash_message/1 — generic shapes" do
    test "map with binary :message" do
      assert Errors.format_flash_message(%{message: "ka-boom"}) == "ka-boom"
    end

    test "binary string falls through unchanged" do
      assert Errors.format_flash_message("plain") == "plain"
    end

    test "anything else is wrapped in 'An error occurred: …'" do
      assert Errors.format_flash_message(:weird) == "An error occurred: :weird"
      assert Errors.format_flash_message({:oops, 1}) == "An error occurred: {:oops, 1}"
      assert Errors.format_flash_message(nil) == "An error occurred: nil"
    end
  end

  describe "extract_error_message/1" do
    test "Ash.Error.Invalid joins ALL errors (no take limit)" do
      err = %Ash.Error.Invalid{
        errors: [%{message: "a"}, %{message: "b"}, %{message: "c"}, %{message: "d"}]
      }

      assert Errors.extract_error_message(err) == "a, b, c, d"
    end

    test "map with :message" do
      assert Errors.extract_error_message(%{message: "Invalid email"}) == "Invalid email"
    end

    test "map with :field and :message" do
      assert Errors.extract_error_message(%{field: :email, message: "is invalid"}) ==
               "email: is invalid"
    end

    test "binary string passes through" do
      assert Errors.extract_error_message("just text") == "just text"
    end

    test "anything else is inspected" do
      assert Errors.extract_error_message(:atom) == ":atom"
      assert Errors.extract_error_message({:tuple, 1}) == "{:tuple, 1}"
      assert Errors.extract_error_message(nil) == "nil"
    end
  end

  describe "Splode classes attached to error structs" do
    test "Action.Failed exception carries class :action" do
      err = Failed.exception(action: :archive, reason: "x")
      assert err.class == :action
    end

    test "Data.LoadFailed exception carries class :data" do
      err = LoadFailed.exception(resource: SomeResource, reason: "x")
      assert err.class == :data
    end

    test "to_error/1 on a non-Splode value returns an Errors.Unknown" do
      wrapped = Errors.to_error(:something)
      assert wrapped.__struct__ == MishkaGervaz.Errors.Unknown
    end
  end
end
