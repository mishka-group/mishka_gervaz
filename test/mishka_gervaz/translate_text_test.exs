defmodule MishkaGervaz.TranslateTextTest do
  @moduledoc """
  A string a resource's DSL holds is translated when it is drawn, in the caller's locale, through
  the `:gettext_backend` and the `mishka_gervaz` domain. The Persian messages are in
  `test/support/gettext/fa`; no message there is a message of the default backend, so a string that
  is translated went through the configured one.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Helpers
  alias MishkaGervaz.Messages

  @backend MishkaGervaz.Test.Gettext

  doctest MishkaGervaz.Messages, only: [translate_text: 1]

  doctest MishkaGervaz.Helpers,
    only: [
      translate_text: 1,
      resolve_label: 1,
      resolve_dynamic: 2,
      resolve_confirm: 2,
      resolve_ui_label: 1,
      get_ui_label: 1,
      resolve_translated_options: 1,
      translate_options: 1,
      action_label: 1
    ]

  setup do
    Gettext.put_locale(@backend, "fa")
    :ok
  end

  describe "Messages.translate_text/1" do
    test "translates a binary in the caller's locale" do
      assert Messages.translate_text("Heading") == "سرتیتر"
    end

    test "gives the string back when the locale has no message for it" do
      assert Messages.translate_text("A string nobody translated") == "A string nobody translated"
    end

    test "gives the string back in a locale with no messages at all" do
      Gettext.put_locale(@backend, "en")

      assert Messages.translate_text("Heading") == "Heading"
    end

    test "is the caller's locale, not a global one" do
      task =
        Task.async(fn ->
          Gettext.put_locale(@backend, "en")
          Messages.translate_text("Heading")
        end)

      assert Task.await(task) == "Heading"
      assert Messages.translate_text("Heading") == "سرتیتر"
    end

    test "leaves nil, an empty string and anything that is not a binary alone" do
      fun = fn -> "Heading" end

      assert Messages.translate_text(nil) == nil
      assert Messages.translate_text("") == ""
      assert Messages.translate_text(:heading) == :heading
      assert Messages.translate_text(12) == 12
      assert Messages.translate_text(fun) == fun
    end

    test "does not interpolate a string that holds a placeholder" do
      assert Messages.translate_text("%{count} left") == "%{count} left"
    end
  end

  describe "Helpers.resolve_label/1" do
    test "translates a string" do
      assert Helpers.resolve_label("Heading") == "سرتیتر"
    end

    test "calls a function and returns what it returned" do
      assert Helpers.resolve_label(fn -> "Heading" end) == "Heading"

      assert Helpers.resolve_label(fn ->
               Gettext.dgettext(@backend, "mishka_gervaz", "Heading")
             end) == "سرتیتر"
    end

    test "keeps nil" do
      assert Helpers.resolve_label(nil) == nil
    end

    test "gives an untranslated string back byte for byte" do
      assert Helpers.resolve_label("Static Label") == "Static Label"
    end
  end

  describe "Helpers.resolve_confirm/2" do
    test "translates a string" do
      assert Helpers.resolve_confirm("Delete this draft?", %{id: 1}) == "این پیش‌نویس حذف شود؟"
    end

    test "calls a function with the record and returns what it returned" do
      assert Helpers.resolve_confirm(fn record -> "Delete #{record.name}?" end, %{name: "Cat"}) ==
               "Delete Cat?"
    end

    test "keeps nil" do
      assert Helpers.resolve_confirm(nil, %{id: 1}) == nil
    end
  end

  describe "Helpers.resolve_ui_label/1 and get_ui_label/1" do
    test "translate a ui label that is a string, whether the ui is a map or a struct" do
      assert Helpers.resolve_ui_label(%{ui: %{label: "Heading"}}) == "سرتیتر"

      assert Helpers.resolve_ui_label(%{
               ui: %MishkaGervaz.Table.Entities.Column.Ui{label: "Heading"}
             }) == "سرتیتر"
    end

    test "call a ui label that is a function and return what it returned" do
      assert Helpers.resolve_ui_label(%{ui: %{label: fn -> "Heading" end}}) == "Heading"
    end

    test "translate the humanized name when there is no ui label" do
      assert Helpers.get_ui_label(%{name: :title}) == "عنوان"
      assert Helpers.get_ui_label(%{name: :created_at}) == "Created At"
      assert Helpers.get_ui_label(%{ui: nil, name: :title}) == "عنوان"
    end
  end

  describe "Helpers.resolve_dynamic/2" do
    test "translates a string, calls a function and keeps nil" do
      assert Helpers.resolve_dynamic("Heading", %{}) == "سرتیتر"
      assert Helpers.resolve_dynamic(fn -> "Heading" end, %{}) == "Heading"

      assert Helpers.resolve_dynamic(fn state -> state.title end, %{title: "Heading"}) ==
               "Heading"

      assert Helpers.resolve_dynamic(nil, %{}) == nil
    end
  end

  describe "Helpers.action_label/1" do
    test "is the ui label, translated" do
      assert Helpers.action_label(%{name: :publish, ui: %{label: "Heading"}}) == "سرتیتر"
    end

    test "is the humanized name, translated, when the action has no label" do
      assert Helpers.action_label(%{name: :publish, ui: nil}) == "انتشار"
      assert Helpers.action_label(%{name: :mark_done, ui: %{label: nil}}) == "Mark Done"
    end
  end

  describe "Helpers.translate_options/1" do
    test "translates the label of a {label, value} option and never the value" do
      assert Helpers.translate_options([{"Draft", :draft}, {"Heading", "Heading"}]) ==
               [{"پیش‌نویس", :draft}, {"سرتیتر", "Heading"}]
    end

    test "translates the humanized label of a bare value and of a keyword option" do
      assert Helpers.translate_options([:published, [label: "Small", value: "s"], "Large"]) ==
               [{"منتشر شده", "published"}, {"کوچک", "s"}, {"بزرگ", "Large"}]
    end

    test "translates the label of a group and the options inside it" do
      assert Helpers.translate_options([{"Basic", [{"Draft", :draft}]}]) ==
               [{"پایه", [{"پیش‌نویس", :draft}]}]
    end

    test "returns an option of a shape it does not know as it is" do
      assert Helpers.translate_options([{"a", "b", "c"}]) == [{"a", "b", "c"}]
    end

    test "gives an untranslated option back byte for byte" do
      assert Helpers.translate_options([{"Nobody translated this", 1}]) ==
               [{"Nobody translated this", 1}]
    end
  end

  describe "Helpers.resolve_translated_options/1" do
    test "translates the labels of a list" do
      assert Helpers.resolve_translated_options([{"Draft", :draft}]) == [{"پیش‌نویس", :draft}]
    end

    test "calls a function and returns the list it returned as it is" do
      assert Helpers.resolve_translated_options(fn -> [{"Draft", :draft}] end) ==
               [{"Draft", :draft}]
    end

    test "is an empty list for nil" do
      assert Helpers.resolve_translated_options(nil) == []
    end
  end
end
