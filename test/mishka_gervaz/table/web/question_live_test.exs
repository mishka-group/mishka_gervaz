defmodule MishkaGervaz.Table.Web.QuestionLiveTest do
  @moduledoc """
  The question window a row action, a bulk action and a form's save ask before they act, driven
  the way a reader drives it (`MishkaGervaz.Test.Web.DeskItem` on
  `MishkaGervaz.Test.Web.TablePageLive`'s `/desk`, and its form in the row drawer).

  A press asks and runs nothing; the window's answer runs the very action, Cancel runs nothing. A
  question that asks for a typed answer keeps its button off until the answer is typed, and refuses
  a wrong one with a sentence. A bulk action's question counts the rows it runs on. A form's save
  waits for its question and then saves what was submitted.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.DeskItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @window "#items-question"
  @dialog "#items-question-dialog"
  @confirm ~s|#items-question [data-role="gervaz-question-confirm"]|

  setup do
    on_exit(fn -> DeskItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    :ok
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/desk")
    render_async(view)
    view
  end

  defp ask(view, action, record) do
    view
    |> element(
      ~s|#items [phx-click="ask"][phx-value-question="#{action}"][phx-value-record="#{record.id}"]|
    )
    |> render_click()
  end

  defp gone?(record), do: match?({:error, _}, Ash.get(DeskItem, record.id))

  describe "a row action" do
    test "asks in the window and runs nothing until it is answered" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()

      ask(view, :remove, lamp)

      assert has_element?(view, "#items-question-title", "Delete Lamp?")
      assert has_element?(view, "#items-question-body", "It cannot be undone.")
      assert has_element?(view, ~s|#{@window}[data-tone="danger"]|)
      assert has_element?(view, @confirm, "Delete")
      refute gone?(lamp)
    end

    test "keeps its button off until the answer is typed, then deletes the row" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()
      ask(view, :remove, lamp)

      assert has_element?(view, "#{@confirm}[disabled]")

      view |> form(@dialog) |> render_change(%{answer: "Lam"})
      assert has_element?(view, "#{@confirm}[disabled]")

      view |> form(@dialog) |> render_change(%{answer: "Lamp"})
      refute has_element?(view, "#{@confirm}[disabled]")

      view |> form(@dialog, %{answer: "Lamp"}) |> render_submit()
      render_async(view)

      refute has_element?(view, @window)
      assert gone?(lamp)
      refute has_element?(view, "#items_desk_items-#{lamp.id}")
    end

    test "refuses a wrong answer with a sentence and deletes nothing" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()
      ask(view, :remove, lamp)

      view |> form(@dialog, %{answer: "lamp"}) |> render_submit()

      assert has_element?(view, "#items-question-error", "Type “Lamp” exactly as it is written.")
      refute gone?(lamp)
    end

    test "Cancel closes the window and runs nothing" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()
      ask(view, :remove, lamp)

      view |> element(~s|#items-question [data-role="gervaz-question-cancel"]|) |> render_click()

      refute has_element?(view, @window)
      refute gone?(lamp)
    end

    test "an event action reaches the page once its question is answered" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()
      ask(view, :mark, lamp)

      assert has_element?(view, ~s|#{@window}[data-tone="info"]|)

      assert has_element?(
               view,
               ~s|#items-question [data-role="gervaz-question-cancel"]|,
               "Not now"
             )

      assert has_element?(view, "#activity", "0")

      view |> form(@dialog) |> render_submit()

      assert has_element?(view, "#activity", "1")
      refute has_element?(view, @window)
    end

    test "a row that is gone asks nothing" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()
      Ash.destroy!(lamp)

      ask(view, :remove, lamp)

      refute has_element?(view, @window)
    end
  end

  test "a bulk action asks about the rows it runs on, then deletes them" do
    [lamp, desk, _chair] =
      Enum.map(["Lamp", "Desk", "Chair"], &Ash.create!(DeskItem, %{title: &1}))

    view = open()

    for item <- [lamp, desk] do
      view
      |> element(~s|#items [phx-click="toggle_select"][phx-value-id="#{item.id}"]|)
      |> render_click()
    end

    view |> element(~s|#items [phx-click="ask"][phx-value-question="wipe"]|) |> render_click()

    assert has_element?(view, "#items-question-title", "Delete 2 items?")
    refute gone?(lamp)

    view |> form(@dialog) |> render_submit()
    render_async(view)

    assert gone?(lamp) and gone?(desk)
    assert DeskItem |> Ash.read!() |> Enum.map(& &1.title) == ["Chair"]
  end

  describe "a form's save" do
    test "waits for its question, then saves what was submitted" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()

      view
      |> element(
        ~s|#items [phx-click="open_drawer"][phx-value-action="edit_here"][phx-value-id="#{lamp.id}"]|
      )
      |> render_click()

      render_async(view)

      view |> form("#items-drawer-form-form", form: %{title: "Desk lamp"}) |> render_submit()

      assert has_element?(view, "#items-drawer-form-question-title", "Save the item?")

      assert has_element?(
               view,
               "#items-drawer-form-question-body",
               "The changes to Lamp are saved."
             )

      assert Ash.get!(DeskItem, lamp.id).title == "Lamp"

      view |> form("#items-drawer-form-question-dialog") |> render_submit()
      render_async(view)

      assert Ash.get!(DeskItem, lamp.id).title == "Desk lamp"
    end

    test "Cancel saves nothing and keeps the form" do
      lamp = Ash.create!(DeskItem, %{title: "Lamp"})
      view = open()

      view
      |> element(
        ~s|#items [phx-click="open_drawer"][phx-value-action="edit_here"][phx-value-id="#{lamp.id}"]|
      )
      |> render_click()

      render_async(view)

      view |> form("#items-drawer-form-form", form: %{title: "Desk lamp"}) |> render_submit()

      view
      |> element(~s|#items-drawer-form-question [data-role="gervaz-question-cancel"]|)
      |> render_click()

      refute has_element?(view, "#items-drawer-form-question")
      assert has_element?(view, "#items-drawer-form-form")
      assert Ash.get!(DeskItem, lamp.id).title == "Lamp"
    end
  end
end
