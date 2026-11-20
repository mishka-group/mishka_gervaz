defmodule MishkaGervaz.Form.Web.ChoiceFieldsLiveTest do
  @moduledoc """
  A `:choice_cards` and a `:segmented` field on a form, a LiveComponent on a page, driven the way an
  admin drives it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  Each option is a radio named `form[<field>]` with its label, and the second line and icon the
  option declares. The radio of the value the form holds is checked: the default on create, a pick
  after a change, the saved value on edit. A save stores the picked value.
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

  defp open(path \\ "/plans") do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp checked(view, name) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{@form} input[type="radio"][name="form[#{name}]"][checked]|)
    |> LazyHTML.attribute("value")
  end

  describe "choice cards" do
    test "draw one radio per option with its label, second line and icon" do
      view = open()
      cards = ~s|#{@form} [data-role="gervaz-choice-cards"][role="radiogroup"]|

      assert has_element?(view, ~s|#{cards} label[data-value="one_time"]|, "One-time")
      assert has_element?(view, ~s|#{cards} label[data-value="one_time"] .hero-bolt|)

      assert has_element?(
               view,
               ~s|#{cards} label[data-value="one_time"] [data-role="gervaz-choice-description"]|,
               "Pay once, keep it"
             )

      assert has_element?(view, ~s|#{cards} label[data-value="subscription"]|, "Subscription")

      refute has_element?(
               view,
               ~s|#{cards} label[data-value="subscription"] [data-role="gervaz-choice-description"]|
             )
    end

    test "start on the attribute's default and follow a pick" do
      view = open()
      assert checked(view, "kind") == ["one_time"]

      view |> form(@form, %{"form" => %{"kind" => "subscription"}}) |> render_change()

      assert checked(view, "kind") == ["subscription"]
    end

    test "are named by the field's label" do
      view = open()
      html = render(view)

      [labelledby] =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(~s|#{@form} [data-role="gervaz-choice-cards"]|)
        |> LazyHTML.attribute("aria-labelledby")

      assert html =~ ~s(id="#{labelledby}")
    end
  end

  describe "a segmented control" do
    test "draws a radio segment per option, the second line under its label" do
      view = open()
      bar = ~s|#{@form} [data-role="gervaz-segmented-control"]|

      assert has_element?(view, ~s|#{bar} label[data-value="monthly"]|, "Monthly")

      assert has_element?(
               view,
               ~s|#{bar} label[data-value="yearly"] [data-role="gervaz-choice-description"]|,
               "Two months free"
             )

      assert checked(view, "billing") == []
    end
  end

  describe "saving" do
    test "stores the picked values" do
      view = open()

      view
      |> form(@form, %{
        "form" => %{"title" => "Kit", "kind" => "subscription", "billing" => "yearly"}
      })
      |> render_submit()

      assert [%{title: "Kit", kind: :subscription, billing: :yearly}] = Ash.read!(PlanItem)
      assert has_element?(view, "#saved", "Kit")
    end

    test "an edit checks the saved values" do
      plan = Ash.create!(PlanItem, %{title: "Kit", kind: :subscription, billing: :monthly})
      view = open("/plans?id=#{plan.id}")

      assert checked(view, "kind") == ["subscription"]
      assert checked(view, "billing") == ["monthly"]
    end
  end
end
