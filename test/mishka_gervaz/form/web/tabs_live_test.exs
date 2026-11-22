defmodule MishkaGervaz.Form.Web.TabsLiveTest do
  @moduledoc """
  A `:tabs` form with `navigation :free`, a LiveComponent on a page, driven the way an admin drives
  it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  The steps are a `tablist`: a click on a tab shows its panel. Save stands on every tab and saves
  from any of them, through the form's `before_save`; there is no Back or Next. A save that fails
  on a field of another tab moves there, marks the tab and sends a flash naming it, and the mark
  goes once the field is fixed.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @tabs ~s|#plan-form-wrapper [role="tablist"]|
  @save ~s|#plan-form button[type="submit"]:not([data-role])|

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/plans")
    render_async(view)
    view
  end

  defp shown_step(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{@form} [data-step]:not([hidden])|)
    |> LazyHTML.attribute("data-step")
  end

  defp tab(view, step), do: element(view, ~s|#{@tabs} [role="tab"][data-step="#{step}"]|)

  defp submit(view, values) do
    view
    |> form(@form, %{"form" => values})
    |> render_submit()
  end

  describe "the tabs" do
    test "are a tablist, the first tab selected and its panel shown" do
      view = open()

      assert has_element?(view, ~s|#{@tabs} [role="tab"][aria-selected="true"]|, "Basics")
      assert has_element?(view, ~s|#{@tabs} [role="tab"][aria-selected="false"]|, "Pricing")
      assert has_element?(view, ~s|#{@tabs} [data-step="pricing"] .hero-banknotes|)
      refute has_element?(view, ~s|#{@tabs} [role="tab"][disabled]|)
      assert shown_step(view) == ["basics"]

      assert has_element?(
               view,
               ~s|#plan-step-basics[role="tabpanel"][aria-labelledby="plan-tab-basics"]|
             )

      assert has_element?(view, ~s|#plan-tab-basics[aria-controls="plan-step-basics"]|)
    end

    test "a click on a tab shows its panel, and any tab may be opened" do
      view = open()

      tab(view, "publishing") |> render_click()
      assert shown_step(view) == ["publishing"]
      assert has_element?(view, ~s|#{@tabs} [aria-selected="true"]|, "Publishing")

      tab(view, "basics") |> render_click()
      assert shown_step(view) == ["basics"]
    end

    test "keep what was typed on another tab" do
      view = open()
      view |> form(@form, %{"form" => %{"title" => "Kit"}}) |> render_change()

      tab(view, "pricing") |> render_click()

      assert has_element?(view, ~s|#{@form} input[name="form[title]"][value="Kit"]|)
    end
  end

  describe "saving" do
    test "Save stands on every tab, with no Back or Next" do
      view = open()

      for step <- ~w(basics pricing publishing) do
        tab(view, step) |> render_click()
        assert has_element?(view, @save)
        refute has_element?(view, ~s|#{@form} [data-role="gervaz-step-next"]|)
        refute has_element?(view, ~s|#{@form} [data-role="gervaz-step-back"]|)
      end
    end

    test "saves from any tab, through before_save" do
      view = open()
      tab(view, "publishing") |> render_click()

      submit(view, %{"title" => "Kit", "slug" => ""})

      assert [%{title: "Kit", slug: "kit"}] = Ash.read!(PlanItem)
      assert has_element?(view, "#saved", "Kit")
    end

    test "a save that fails on another tab moves there, marks it and names it" do
      view = open()
      tab(view, "publishing") |> render_click()

      submit(view, %{"title" => ""})

      assert Ash.read!(PlanItem) == []
      assert shown_step(view) == ["basics"]
      assert has_element?(view, ~s|#{@tabs} [data-step="basics"] [data-role="gervaz-step-error"]|)
      assert has_element?(view, "#flash-error", "Basics")

      view |> form(@form, %{"form" => %{"title" => "Kit"}}) |> render_change()

      refute has_element?(view, ~s|#{@tabs} [data-role="gervaz-step-error"]|)
    end
  end
end
