defmodule MishkaGervaz.Form.Web.StepSaveLiveTest do
  @moduledoc """
  A wizard whose steps say `save true` (`MishkaGervaz.Test.Web.StepItem` on
  `MishkaGervaz.Test.Web.StepPageLive`): Next on such a step saves what the form holds, a create
  first and an update after, tells the page `{:form_saved, mode, record}`, and opens the saved
  record for editing on the next step. A step whose fields hold an error, or a save the action
  refuses, stays where it is with the errors shown.

  A save that keeps its record open keeps its step: the last step of a wizard mounted with a
  `record_id`, and a tab of free tabs (`MishkaGervaz.Test.Web.PlanItem` on
  `MishkaGervaz.Test.Web.PlanPageLive`).
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{PlanItem, StepItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#steps-form"
  @next ~s|#steps-form [data-role="gervaz-step-next"]|
  @back ~s|#steps-form [data-role="gervaz-step-back"]|

  setup do
    on_exit(fn ->
      StepItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
      PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp shown_step(view, form \\ @form) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{form} [data-step]:not([hidden])|)
    |> LazyHTML.attribute("data-step")
  end

  defp next(view, values) do
    assert has_element?(view, @next)
    view |> form(@form, %{"form" => values}) |> render_submit()
    render_async(view)
  end

  defp text(view, selector),
    do:
      view
      |> element(selector)
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.text()
      |> String.trim()

  describe "Next on a step that saves" do
    test "creates the record and opens it for editing on the next step" do
      view = open("/steps")

      next(view, %{"title" => "Draft"})

      assert [%{title: "Draft", body: nil}] = Ash.read!(StepItem)
      assert text(view, "#saved") == "create:Draft"
      assert shown_step(view) == ["content"]
      assert text(view, "#content-extra") == "Editing as update"
      assert text(view, "#step") == "content"
    end

    test "with an error on the step's own fields, saves nothing and stays" do
      view = open("/steps")

      next(view, %{"title" => ""})

      assert Ash.read!(StepItem) == []
      assert text(view, "#saved") == ""
      assert shown_step(view) == ["basics"]
    end

    test "on a later step, updates the same record and moves on" do
      view = open("/steps")
      next(view, %{"title" => "Draft"})

      next(view, %{"body" => "Text"})

      assert [%{title: "Draft", body: "Text"}] = Ash.read!(StepItem)
      assert text(view, "#saved") == "create:Draft,update:Draft"
      assert shown_step(view) == ["review"]
    end

    test "a save the action refuses stays on the step with the error under its field" do
      view = open("/steps")
      next(view, %{"title" => "Draft"})

      next(view, %{"body" => "refused"})

      assert [%{body: nil}] = Ash.read!(StepItem)
      assert text(view, "#saved") == "create:Draft"
      assert shown_step(view) == ["content"]
      assert render(view) =~ "Not this body."
    end

    test "Back reaches the step that saved, holding what was saved" do
      view = open("/steps")
      next(view, %{"title" => "Draft"})

      view |> element(@back) |> render_click()

      assert shown_step(view) == ["basics"]
      assert has_element?(view, ~s|#{@form} input[name="form[title]"][value="Draft"]|)
    end

    test "on a record opened on that step, updates it" do
      record = Ash.create!(StepItem, %{title: "Kept"})
      view = open("/steps?id=#{record.id}&step=content")
      assert shown_step(view) == ["content"]

      next(view, %{"body" => "Later"})

      assert [%{title: "Kept", body: "Later"}] = Ash.read!(StepItem)
      assert shown_step(view) == ["review"]
    end
  end

  describe "a save that keeps its record open keeps its step" do
    test "the last step of a wizard mounted with a record_id" do
      view = open("/steps")
      next(view, %{"title" => "Draft"})
      next(view, %{"body" => "Text"})

      view |> form(@form, %{"form" => %{"note" => "Done"}}) |> render_submit()
      render_async(view)

      assert [%{note: "Done"}] = Ash.read!(StepItem)
      assert text(view, "#saved") == "create:Draft,update:Draft,update:Draft"
      assert shown_step(view) == ["review"]
    end

    test "a tab of free tabs" do
      record = Ash.create!(PlanItem, %{title: "Kit"})
      view = open("/plans?id=#{record.id}&step=pricing")

      view |> form("#plan-form", %{"form" => %{"discount" => "5"}}) |> render_submit()
      render_async(view)

      assert [%{discount: 5}] = Ash.read!(PlanItem)
      assert shown_step(view, "#plan-form") == ["pricing"]
    end
  end
end
