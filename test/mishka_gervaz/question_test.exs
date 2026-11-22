defmodule MishkaGervaz.QuestionTest do
  @moduledoc """
  `MishkaGervaz.Question`: which `confirm` asks in the question window, the question it asks about
  its subject, and when it is answered.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Question

  doctest MishkaGervaz.Question

  test "builds the question about its subject, its functions given the subject" do
    question =
      Question.build(
        [
          title: fn record -> "Delete #{record.name}?" end,
          body: "It cannot be undone.",
          answer: fn record -> record.name end,
          confirm_label: "Delete"
        ],
        %{name: "Lamp"}
      )

    assert %{
             title: "Delete Lamp?",
             body: "It cannot be undone.",
             answer: "Lamp",
             confirm_label: "Delete",
             cancel_label: nil,
             tone: :danger,
             typed: "",
             error: nil
           } = question
  end

  test "puts the count in its strings, and keeps {count} when there is none" do
    confirm = [title: "Delete {count} posts?", body: fn count -> "#{count} at once" end]

    assert %{title: "Delete 3 posts?", body: "3 at once"} = Question.build(confirm, 3, count: 3)
    assert %{title: "Delete {count} posts?"} = Question.build(confirm, nil, count: nil)
  end

  test "a string or a function confirm is not a question" do
    assert Question.build("Sure?", %{}) == nil
    assert Question.build(fn _record -> "Sure?" end, %{}) == nil
    assert Question.build(nil, %{}) == nil
  end

  test "an unknown tone is danger" do
    assert %{tone: :info} = Question.build([title: "Go?", tone: :info], nil)
    assert %{tone: :danger} = Question.build([title: "Go?", tone: :loud], nil)
  end

  test "a refusal names the answer, and typing again clears it" do
    question = [title: "Delete?", answer: "Lamp"] |> Question.build(nil) |> Question.refuse()

    assert question.error =~ "“Lamp”"
    assert %{error: nil, typed: "La"} = Question.put_typed(question, "La")
  end

  test "keeps the event it runs and its values" do
    question = [title: "Go?"] |> Question.build(nil) |> Question.pending("delete", %{"id" => "1"})

    assert %{event: "delete", params: %{"id" => "1"}} = question
  end
end
