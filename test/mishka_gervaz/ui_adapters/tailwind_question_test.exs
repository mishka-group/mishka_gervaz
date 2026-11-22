defmodule MishkaGervaz.UIAdapters.TailwindQuestionTest do
  @moduledoc """
  The default adapter's `question/1`: an alert dialog over a backdrop with a title, a sentence and
  two buttons in the tone's colour. Its button answers through the form's submit, and Cancel, the
  backdrop and Escape send `on_cancel`. With an `answer`, a field asks for it and the button stays
  off until it is typed; a refusal is said under the field.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.UIAdapters.Tailwind

  defp render(assigns) do
    %{
      __changed__: nil,
      id: "ask",
      title: "Delete Lamp?",
      on_confirm: "question_confirm",
      on_change: "question_typed",
      on_cancel: "question_cancel"
    }
    |> Map.merge(assigns)
    |> Tailwind.question()
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp one(doc, selector), do: LazyHTML.query(doc, selector)
  defp attr(doc, selector, name), do: doc |> one(selector) |> LazyHTML.attribute(name)
  defp text(doc, selector), do: doc |> one(selector) |> LazyHTML.text() |> String.trim()

  test "is a labelled alert dialog with its sentence, answered by its form" do
    doc = render(%{body: "It cannot be undone.", tone: :warn})

    assert attr(doc, "#ask-dialog", "role") == ["alertdialog"]
    assert attr(doc, "#ask-dialog", "aria-modal") == ["true"]
    assert attr(doc, "#ask-dialog", "aria-labelledby") == ["ask-title"]
    assert attr(doc, "#ask-dialog", "aria-describedby") == ["ask-body"]
    assert text(doc, "#ask-title") == "Delete Lamp?"
    assert text(doc, "#ask-body") == "It cannot be undone."
    assert attr(doc, "#ask", "data-tone") == ["warn"]
    assert attr(doc, "#ask-dialog", "phx-submit") == ["question_confirm"]
    assert attr(doc, ~s|[data-role="gervaz-question-confirm"]|, "type") == ["submit"]
  end

  test "Cancel, the backdrop and Escape send on_cancel" do
    doc = render(%{})

    assert attr(doc, ~s|[data-role="gervaz-question-cancel"]|, "phx-click") == ["question_cancel"]
    assert attr(doc, "#ask-backdrop", "phx-click") == ["question_cancel"]
    assert attr(doc, "#ask", "phx-window-keydown") == ["question_cancel"]
    assert attr(doc, "#ask", "phx-key") == ["escape"]
  end

  test "reads Cancel and Confirm unless given its own labels" do
    plain = render(%{})
    assert text(plain, ~s|[data-role="gervaz-question-cancel"]|) == "Cancel"
    assert text(plain, ~s|[data-role="gervaz-question-confirm"]|) == "Confirm"

    own = render(%{confirm_label: "Delete product", cancel_label: "Keep it"})
    assert text(own, ~s|[data-role="gervaz-question-cancel"]|) == "Keep it"
    assert text(own, ~s|[data-role="gervaz-question-confirm"]|) == "Delete product"
  end

  test "with an answer, asks for it and keeps its button off until it is typed" do
    asked = render(%{answer: "Lamp", typed: "La"})

    assert attr(asked, "#ask-answer", "name") == ["answer"]
    assert attr(asked, "#ask-answer", "value") == ["La"]
    assert text(asked, ~s|label[for="ask-answer"]|) =~ "Lamp"
    assert attr(asked, "#ask-dialog", "phx-change") == ["question_typed"]
    assert attr(asked, ~s|[data-role="gervaz-question-confirm"]|, "disabled") == [""]

    typed = render(%{answer: "Lamp", typed: "Lamp"})
    assert attr(typed, ~s|[data-role="gervaz-question-confirm"]|, "disabled") == []
  end

  test "without an answer, draws no field and the button is on" do
    doc = render(%{})

    assert one(doc, "#ask-answer") |> Enum.count() == 0
    assert attr(doc, "#ask-dialog", "phx-change") == []
    assert attr(doc, ~s|[data-role="gervaz-question-confirm"]|, "disabled") == []
  end

  test "says a refusal under the field" do
    doc = render(%{answer: "Lamp", typed: "lamp", error: "Type “Lamp” exactly as it is written."})

    assert attr(doc, "#ask-error", "role") == ["alert"]
    assert text(doc, "#ask-error") =~ "Type “Lamp”"
    assert attr(doc, "#ask-answer", "aria-describedby") == ["ask-error"]
  end
end
