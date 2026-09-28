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
  alias MishkaGervaz.Test.Resources.TranslatedLabels

  use Gettext, backend: MishkaGervaz.Test.Gettext

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

    test "field-shaped error names the field in words" do
      err = %Ash.Error.Invalid{errors: [%{field: :email, message: "is invalid"}]}
      assert Errors.format_flash_message(err) == "Validation failed: Email is invalid"
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

    test "map with :field and :message names the field in words" do
      assert Errors.extract_error_message(%{field: :email, message: "is invalid"}) ==
               "Email is invalid"

      assert Errors.extract_error_message(%{field: :language_group_id, message: "is invalid"}) ==
               "Language group is invalid"
    end

    test "a message written as a sentence is shown without its field" do
      message = "This is the Persian translation. Restore the original first, then this one."

      assert Errors.extract_error_message(%{field: :language_group_id, message: message}) ==
               message
    end

    test "placeholders are filled from the error's vars" do
      error = %{field: :title, message: "must be at least %{min}", vars: [min: 3]}

      assert Errors.extract_error_message(error) == "Title must be at least 3"
    end

    test "an Ash error with a field reads the same way" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(field: :parent_id, message: "is invalid")

      assert Errors.format_flash_message(%Ash.Error.Invalid{errors: [error]}) ==
               "Validation failed: Parent is invalid"
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

  describe "a message about a field" do
    test "ends a sentence by its last character, not by a capital letter" do
      for message <- ["that label is archived.", "Restore it first!", "Is it archived?"] do
        assert Errors.extract_error_message(%{field: :tag_id, message: message}) == message
      end

      assert Errors.extract_error_message(%{field: :tag_id, message: "Must be archived"}) ==
               "Tag Must be archived"
    end

    test "a closing quote or bracket after the full stop still ends a sentence" do
      message = ~s(The note says "archived.")

      assert Errors.extract_error_message(%{field: :note_id, message: message}) == message
    end

    test "an error about the whole form names no field" do
      assert Errors.extract_error_message(%{field: :_form, message: "is invalid"}) ==
               "is invalid"
    end

    test "names the field by the form field's label" do
      error = %{field: :title, message: "is required"}

      assert Errors.extract_error_message(error, TranslatedLabels) == "Post title is required"
    end

    test "names the field by its column's label when the form has none" do
      error = %{field: :slug, message: "is required"}

      assert Errors.extract_error_message(error, TranslatedLabels) == "Web address is required"
    end

    test "names a field the resource gives no label by its humanized name" do
      error = %{field: :category_id, message: "is invalid"}

      assert Errors.extract_error_message(error, TranslatedLabels) == "Category is invalid"
    end

    test "an Ash error the form shows reads the same way in a flash" do
      error = Ash.Error.Changes.Required.exception(field: :title, type: :attribute)

      assert Errors.format_flash_message(%Ash.Error.Invalid{errors: [error]}, TranslatedLabels) ==
               "Validation failed: Post title is required"
    end

    test "an action's flash names its fields by the action's resource" do
      reason = %Ash.Error.Invalid{errors: [%{field: :title, message: "is required"}]}

      error =
        Failed.exception(
          resource: TranslatedLabels,
          action: :publish_post,
          label: "Publish",
          reason: reason
        )

      assert Errors.format_flash_message(error) == "Publish failed: Post title is required"
    end
  end

  describe "in Persian" do
    setup do
      Gettext.put_locale(MishkaGervaz.Test.Gettext, "fa")
      :ok
    end

    test "a Persian sentence is shown as written, with no field in front" do
      for message <- [
            "این برچسب را این سایت نمی‌تواند به کار ببرد.",
            "آیا این برچسب بایگانی شده است؟"
          ] do
        assert Errors.extract_error_message(%{field: :tag_id, message: message}, TranslatedLabels) ==
                 message
      end
    end

    test "an English sentence translated to Persian is shown as the translation, alone" do
      error = %{field: :label_id, message: "That label is not one this site can use."}

      assert Errors.extract_error_message(error) ==
               "این برچسب را این سایت نمی‌تواند به کار ببرد."
    end

    test "a fragment is joined to the translated label through the translated template" do
      error = %{field: :title, message: "is required"}

      assert Errors.extract_error_message(error, TranslatedLabels) == "«عنوان نوشته» الزامی است"
    end

    test "a field with no label is named by its humanized name, translated" do
      error = %{field: :category_id, message: "is invalid"}

      assert Errors.extract_error_message(error, TranslatedLabels) == "«دسته» نامعتبر است"
    end

    test "a column's label names the field when the form has none" do
      error = %{field: :slug, message: "is invalid"}

      assert Errors.extract_error_message(error, TranslatedLabels) == "«نشانی وب» نامعتبر است"
    end

    test "placeholders are filled after the message is translated" do
      error = %{
        field: :title,
        message: "length must be greater than or equal to %{min}",
        vars: [min: 3]
      }

      assert Errors.extract_error_message(error, TranslatedLabels) ==
               "«عنوان نوشته» باید دست‌کم 3 نویسه باشد"
    end

    test "a message with a count is translated as a plural" do
      error = %{
        field: :title,
        message: "should be at least %{count} character(s)",
        vars: [count: 3]
      }

      assert Errors.extract_error_message(error, TranslatedLabels) ==
               "«عنوان نوشته» باید دست‌کم 3 نویسه باشد"
    end

    test "an action's flash reads in Persian, its action named by its label" do
      reason = %Ash.Error.Invalid{
        errors: [
          Ash.Error.Changes.Required.exception(field: :title, type: :attribute),
          %{field: :category_id, message: "is invalid"}
        ]
      }

      error =
        Failed.exception(
          resource: TranslatedLabels,
          action: :publish_post,
          label: fn -> dgettext("mishka_gervaz", "Publish") end,
          reason: reason
        )

      assert Errors.format_flash_message(error) ==
               "انتشار انجام نشد: «عنوان نوشته» الزامی است، «دسته» نامعتبر است"
    end

    test "an action with no label is named by its humanized name, translated" do
      error = Failed.exception(action: :permanent_destroy, reason: "forbidden")

      assert Errors.format_flash_message(error) == "حذف همیشگی انجام نشد: forbidden"
    end

    test "several failed records are counted in Persian" do
      reason = {:bulk_action_failed, :error, [%{message: "a"}, %{message: "b"}]}
      error = Failed.exception(action: :permanent_destroy, reason: reason)

      assert Errors.format_flash_message(error) == "حذف همیشگی انجام نشد: 2 خطا رخ داد"
    end

    test "a failed load and a validation failure read in Persian" do
      invalid = %Ash.Error.Invalid{errors: [%{field: :title, message: "is required"}]}

      assert Errors.format_flash_message(invalid, TranslatedLabels) ==
               "داده‌ها پذیرفته نشد: «عنوان نوشته» الزامی است"

      assert Errors.format_flash_message(LoadFailed.exception(resource: nil, reason: "timeout")) ==
               "داده‌ها بار نشد: timeout"
    end
  end

  describe "an Ash error that names no field" do
    test "a changeset error added as a sentence is shown in the flash" do
      [error] =
        TranslatedLabels
        |> Ash.Changeset.new()
        |> Ash.Changeset.add_error("That tag is archived.")
        |> Map.fetch!(:errors)

      reason = %Ash.Error.Invalid{errors: [error, error]}

      assert Errors.extract_error_message(error, TranslatedLabels) == "That tag is archived."

      assert Errors.format_flash_message(Failed.exception(action: :destroy, reason: reason)) ==
               "Destroy failed: That tag is archived."
    end

    test "a query error with a message and no field is shown in the flash" do
      [error] =
        TranslatedLabels
        |> Ash.Query.new()
        |> Ash.Query.add_error(message: "You cannot read these.")
        |> Map.fetch!(:errors)

      assert Errors.format_flash_message(LoadFailed.exception(reason: error)) ==
               "Failed to load data: You cannot read these."
    end

    test "a record not found with no primary key says so in words" do
      error = Ash.Error.Query.NotFound.exception(resource: TranslatedLabels)

      assert Errors.format_flash_message(
               Failed.exception(action: :destroy, reason: %Ash.Error.Invalid{errors: [error]})
             ) == "Destroy failed: This record is no longer here."
    end

    test "reads in Persian" do
      Gettext.put_locale(MishkaGervaz.Test.Gettext, "fa")
      error = Ash.Error.Changes.InvalidChanges.exception(message: "That tag is archived.")

      assert Errors.format_flash_message(
               Failed.exception(action: :permanent_destroy, reason: error)
             ) == "حذف همیشگی انجام نشد: این برچسب بایگانی شده است."
    end
  end

  describe "a failure that is not a validation error" do
    test "a record that is gone says so in words" do
      error = Failed.exception(action: :unarchive, label: "Bring back", reason: :not_found)

      assert Errors.format_flash_message(error) ==
               "Bring back failed: This record is no longer here."
    end

    test "a policy refusal says the admin may not do it" do
      reason =
        Ash.Error.to_error_class(Ash.Error.Forbidden.Policy.exception(resource: TranslatedLabels))

      assert Errors.format_flash_message(Failed.exception(action: :destroy, reason: reason)) ==
               "Destroy failed: You are not allowed to do this."
    end

    test "a policy refusal with its own message shows that message" do
      reason =
        Ash.Error.to_error_class(
          Ash.Error.Forbidden.Policy.exception(
            resource: TranslatedLabels,
            custom_message: "That label is not one this site can use."
          )
        )

      assert Errors.format_flash_message(Failed.exception(action: :destroy, reason: reason)) ==
               "Destroy failed: That label is not one this site can use."
    end

    test "an unknown error shows its own words" do
      reason =
        Ash.Error.to_error_class(Ash.Error.Unknown.UnknownError.exception(error: "db down"))

      assert Errors.format_flash_message(Failed.exception(action: :destroy, reason: reason)) ==
               "Destroy failed: db down"

      assert Errors.format_flash_message(reason) == "db down"
    end

    test "reads in Persian" do
      Gettext.put_locale(MishkaGervaz.Test.Gettext, "fa")

      assert Errors.format_flash_message(Failed.exception(action: :destroy, reason: :not_found)) ==
               "حذف انجام نشد: این رکورد دیگر اینجا نیست."

      forbidden =
        Ash.Error.to_error_class(Ash.Error.Forbidden.Policy.exception(resource: TranslatedLabels))

      assert Errors.format_flash_message(Failed.exception(action: :destroy, reason: forbidden)) ==
               "حذف انجام نشد: شما اجازهٔ این کار را ندارید."
    end
  end

  describe "a message with a placeholder its vars do not fill" do
    test "is shown as written, logs nothing and makes no atom" do
      key = "zz_unbound_#{System.unique_integer([:positive])}"
      message = "bad value %{#{key}}"

      log =
        ExUnit.CaptureLog.capture_log([level: :error], fn ->
          assert Errors.translate_error(message, []) == message

          assert Errors.format_flash_message(%RuntimeError{message: message}) == message

          assert Errors.extract_error_message(%{field: :title, message: message}) ==
                   "Title #{message}"
        end)

      refute log =~ "missing Gettext bindings"
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end

    test "a placeholder its vars fill is still translated" do
      Gettext.put_locale(MishkaGervaz.Test.Gettext, "fa")

      assert Errors.translate_error("length must be greater than or equal to %{min}", min: 3) ==
               "باید دست‌کم 3 نویسه باشد"
    end
  end

  describe "in English" do
    test "reads as it did before translation" do
      Gettext.put_locale(MishkaGervaz.Test.Gettext, "en")

      reason = %Ash.Error.Invalid{
        errors: [
          %{field: :title, message: "is required"},
          %{
            field: :title,
            message: "length must be greater than or equal to %{min}",
            vars: [min: 3]
          }
        ]
      }

      error =
        Failed.exception(resource: TranslatedLabels, action: :permanent_destroy, reason: reason)

      assert Errors.format_flash_message(error) ==
               "Permanent destroy failed: Post title is required, Post title length must be greater than or equal to 3"
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
