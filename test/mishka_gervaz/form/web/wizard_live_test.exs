defmodule MishkaGervaz.Form.Web.WizardLiveTest do
  @moduledoc """
  A `:wizard` form, a LiveComponent on a page, driven the way an admin drives it
  (`MishkaGervaz.Test.Web.WizardItem` on `MishkaGervaz.Test.Web.FormPageLive`).

  Next and Back move the form itself, never the page around it. Next checks the step's own fields
  first and shows their errors only; Enter in a field (the form's submit) on any step but the last
  is Next and saves nothing; Back keeps what was typed; the submit button is drawn on the last step
  only, reading its `loading_label` while the save runs. A save that fails on a field of an earlier
  step goes back to that step with the error under the field and an error flash naming the step. A
  form saved starts over on its first step.

  A group declared `collapsed` starts closed and opens when one of its fields shows an error, and a
  `:select` whose options are a function of the form state follows what the form holds.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.WizardItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#wizard-form"
  @next ~s|#wizard-form [data-role="gervaz-step-next"]|
  @back ~s|#wizard-form [data-role="gervaz-step-back"]|
  @submit ~s|#wizard-form button[type="submit"]:not([data-role])|

  setup do
    on_exit(fn -> WizardItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/wizard")
    view
  end

  # The step whose groups are shown: the one `data-step` container in the form not `hidden`.
  defp shown_step(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{@form} [data-step]:not([hidden])|)
    |> LazyHTML.attribute("data-step")
  end

  # Next is the form's submit button, so pressing it, or Enter in a field, submits the form.
  defp next(view, values \\ %{}) do
    assert has_element?(view, ~s|#{@next}[type="submit"]|)
    submit(view, values)
  end

  defp submit(view, values \\ %{}) do
    view
    |> form(@form, %{"form" => values})
    |> render_submit()
  end

  describe "Next and Back" do
    test "move the form's own steps, never the page's" do
      view = open()
      assert shown_step(view) == ["where"]
      refute has_element?(view, @back)

      next(view, %{"title" => "Hello", "address" => "site.example"})
      assert shown_step(view) == ["what"]

      view |> element(@back) |> render_click()
      assert shown_step(view) == ["where"]
      assert Process.alive?(view.pid)
    end

    test "Back keeps what was typed on every step" do
      view = open()
      next(view, %{"title" => "Hello", "address" => "site.example"})
      next(view, %{"kind" => "page"})

      view |> element(@back) |> render_click()
      view |> element(@back) |> render_click()

      assert has_element?(view, ~s|#{@form} input[name="form[title]"][value="Hello"]|)

      assert has_element?(
               view,
               ~s|#{@form} select[name="form[kind]"] option[value="page"][selected]|
             )
    end

    test "Next stays on a step with an error and shows that step's errors only" do
      view = open()

      next(view, %{"title" => "", "address" => "site.example"})

      assert shown_step(view) == ["where"]
      assert has_element?(view, ~s|nav [data-step="where"][data-status="error"]|)
      assert render(view) =~ "is required"

      next(view, %{"title" => "Hello"})
      assert shown_step(view) == ["what"]
      assert has_element?(view, ~s|nav [data-step="where"][data-status="completed"]|)
      refute render(view) =~ "is required"
    end

    test "the error of a refused step follows what is typed until it moves on" do
      view = open()
      next(view, %{"title" => "", "address" => ""})
      assert render(view) =~ "is required"

      view
      |> form(@form, %{"form" => %{"title" => "Hello", "address" => "site.example"}})
      |> render_change()

      refute render(view) =~ "is required"
      assert shown_step(view) == ["where"]
    end
  end

  describe "Enter and the submit button" do
    test "the form's submit on a step before the last saves nothing" do
      view = open()

      submit(view, %{"title" => "Hello", "address" => "site.example"})
      submit(view, %{"kind" => "post"})

      assert shown_step(view) == ["review"]
      assert Ash.read!(WizardItem) == []
    end

    test "the submit button is drawn on the last step only, and saves there" do
      view = open()
      refute has_element?(view, @submit)
      assert has_element?(view, @next)

      next(view, %{"title" => "Hello", "address" => "site.example"})
      refute has_element?(view, @submit)

      next(view, %{"kind" => "post", "language" => "de"})
      assert has_element?(view, @submit, "Save")
      assert has_element?(view, ~s|#{@submit}[phx-disable-with="Checking the address…"]|)
      refute has_element?(view, @next)

      submit(view)

      assert [%{title: "Hello", address: "site.example", kind: "post", language: "de"}] =
               Ash.read!(WizardItem)

      assert has_element?(view, "#saved", "Hello")
      assert shown_step(view) == ["where"]
    end
  end

  describe "a save that fails on an earlier step" do
    test "goes back to that step with the error under its field and a flash naming it" do
      view = open()
      next(view, %{"title" => "Hello", "address" => "refused.example"})
      next(view, %{"kind" => "post"})
      assert shown_step(view) == ["review"]

      submit(view)

      assert shown_step(view) == ["where"]
      assert render(view) =~ "Nothing answered at this address."
      assert has_element?(view, ~s|nav [data-step="where"][data-status="error"]|)
      assert has_element?(view, "#flash-error", "Nothing answered at this address.")
      assert has_element?(view, "#flash-error", "step 1, Where from")
      assert Ash.read!(WizardItem) == []

      next(view, %{"address" => "site.example"})
      next(view)
      submit(view)

      assert [%{address: "site.example"}] = Ash.read!(WizardItem)
    end
  end

  describe "a collapsed group" do
    test "starts closed and keeps the reader's choice through a redraw" do
      view = open()
      next(view, %{"title" => "Hello", "address" => "site.example"})
      next(view)

      assert has_element?(view, ~s|[data-group="advanced"] details summary|, "Advanced")
      refute has_element?(view, ~s|[data-group="advanced"] details[open]|)
      assert has_element?(view, ~s|[data-group="advanced"] details[phx-mounted]|)
    end
  end

  describe "a select whose options are a function of the form state" do
    test "draws the options the function gives for what the form holds" do
      view = open()
      next(view, %{"title" => "Hello", "address" => "site.example"})

      assert has_element?(view, ~s|select[name="form[language]"] option[value="de"]|, "Deutsch")
      refute has_element?(view, ~s|select[name="form[language]"] option[value="page"]|)

      view |> form(@form, %{"form" => %{"kind" => "page"}}) |> render_change()

      assert has_element?(
               view,
               ~s|select[name="form[language]"] option[value="page"]|,
               "Page language"
             )
    end
  end
end
