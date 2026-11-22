defmodule MishkaGervaz.Form.Web.BooleanNoteLiveTest do
  @moduledoc """
  A `:toggle` or `:checkbox` field's `ui` `note` on a form, a LiveComponent on a page, driven the
  way an admin drives it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  The note stands beside the control inside its `<label>`, so a click on it flips the control; the
  field's label stays above and its help text (`description`) under it.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/plans")
    render_async(view)
    view
  end

  test "a toggle's note stands beside the switch, in the switch's label" do
    view = open()

    assert has_element?(
             view,
             ~s|#{@form} label:has(input[role="switch"][name="form[listed]"]) [data-role="gervaz-toggle-note"]|,
             "Buyers find it in the store"
           )
  end

  test "a toggle keeps its label above and its help text under the switch" do
    view = open()
    box = ~s|#{@form} [data-role="gervaz-boolean-control"]:has([name="form[listed]"])|

    refute view |> element(box) |> render() =~ "Turn it off to keep a draft"
    assert has_element?(view, ~s|#{@form} label[for="plan-form_listed"]|, "Listed")

    assert has_element?(
             view,
             ~s|#{@form} [data-role="gervaz-field-description"]|,
             "Turn it off to keep a draft"
           )
  end

  test "a checkbox's note stands beside the box, in the box's label" do
    view = open()

    assert has_element?(
             view,
             ~s|#{@form} label:has(input[type="checkbox"][name="form[featured]"])|,
             "Shown first on the home page"
           )
  end

  test "a switch and a box flipped on are saved as true" do
    view = open()

    view
    |> form(@form, %{"form" => %{"title" => "Kit", "listed" => "true", "featured" => "true"}})
    |> render_submit()

    assert [%{listed: true, featured: true}] = Ash.read!(PlanItem)
  end
end
