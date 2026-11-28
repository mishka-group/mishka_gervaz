defmodule MishkaGervaz.Form.Web.DefaultsLiveTest do
  @moduledoc """
  A page passes live data as a form's `defaults` and refreshes it while the form is open
  (`MishkaGervaz.Test.Web.PlanPageLive` on `/plans?shop=Aurora`, its `:tabs` form of
  `MishkaGervaz.Test.Web.PlanItem`). Defaults no field reads reach the form's notices and leave
  the form as it is; a field's new default is drawn only by a create form with no changes.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @tabs ~s|#plan-form-wrapper [role="tablist"]|
  @listed_on ~s|#plan-form input[role="switch"][name="form[listed]"][checked]|

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/plans?shop=Aurora")
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

  defp change(view, values), do: view |> form(@form, %{"form" => values}) |> render_change()

  defp title(value), do: ~s|#{@form} input[name="form[title]"][value="#{value}"]|

  describe "defaults no field reads" do
    test "change while the form holds changes, and it keeps what was set and its tab" do
      view = open()
      change(view, %{"title" => "Kit"})
      tab(view, "publishing") |> render_click()
      change(view, %{"title" => "Kit", "listed" => "true"})

      view |> element("#rename-shop") |> render_click()

      assert shown_step(view) == ["publishing"]
      assert has_element?(view, @listed_on)
      assert has_element?(view, title("Kit"))

      view |> form(@form, %{"form" => %{"title" => "Kit", "listed" => "true"}}) |> render_submit()

      assert [%{title: "Kit", listed: true}] = Ash.read!(PlanItem)
    end

    test "are what the form's notices read once they change" do
      view = open()
      assert has_element?(view, "#plan-form-wrapper", "Sold in Aurora")

      tab(view, "publishing") |> render_click()
      view |> element("#rename-shop") |> render_click()

      assert has_element?(view, "#plan-form-wrapper", "Sold in Aurora 2")
      assert shown_step(view) == ["publishing"]
    end
  end

  describe "a field's new default" do
    test "is drawn by a create form with no changes" do
      view = open()

      view |> element("#default-title") |> render_click()
      render_async(view)

      assert has_element?(view, title("From the page"))
    end

    test "leaves what was typed in a form with changes" do
      view = open()
      change(view, %{"title" => "Kit"})

      view |> element("#default-title") |> render_click()

      assert has_element?(view, title("Kit"))
      refute has_element?(view, title("From the page"))
    end
  end
end
