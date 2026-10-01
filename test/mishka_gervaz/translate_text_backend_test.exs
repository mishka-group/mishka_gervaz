defmodule MishkaGervaz.TranslateTextBackendTest do
  @moduledoc """
  A string from the DSL is translated through whichever backend `:gettext_backend` names when it is
  drawn, so a host that switches it is read through its own messages.

  This changes the application environment, so it does not run beside the tests that read it.
  """
  use ExUnit.Case, async: false

  alias MishkaGervaz.Helpers
  alias MishkaGervaz.Messages
  alias MishkaGervaz.Table.Types.Action.PermanentDestroy

  @test_backend MishkaGervaz.Test.Gettext
  @other_backend MishkaGervaz.Test.OtherGettext

  setup do
    previous = Application.get_env(:mishka_gervaz, :gettext_backend)
    on_exit(fn -> Application.put_env(:mishka_gervaz, :gettext_backend, previous) end)

    Gettext.put_locale(@test_backend, "fa")
    Gettext.put_locale(@other_backend, "fa")
    :ok
  end

  defp use_backend(backend), do: Application.put_env(:mishka_gervaz, :gettext_backend, backend)

  test "translate_text reads the configured backend" do
    use_backend(@test_backend)
    assert Messages.translate_text("Heading") == "سرتیتر"

    use_backend(@other_backend)
    assert Messages.translate_text("Heading") == "تیتر"
  end

  test "resolve_label and resolve_confirm read the configured backend" do
    use_backend(@other_backend)

    assert Helpers.resolve_label("Heading") == "تیتر"
    assert Helpers.resolve_confirm("Delete this draft?", %{}) == "پیش‌نویس پاک شود؟"
  end

  test "a backend with no message for a string gives the string back" do
    use_backend(@other_backend)

    assert Helpers.resolve_label("Title") == "Title"
  end

  test "an action's confirm is read through the configured backend" do
    use_backend(@other_backend)

    action = %{ui: %{}, confirm: "Delete this draft?", name: :wipe}
    record = %{id: "1"}

    html =
      PermanentDestroy.render(%{}, action, record, MishkaGervaz.UIAdapters.Tailwind, nil)
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    assert html =~ ~s(data-confirm="پیش‌نویس پاک شود؟")
  end
end
