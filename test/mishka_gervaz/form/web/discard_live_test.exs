defmodule MishkaGervaz.Form.Web.DiscardLiveTest do
  @moduledoc """
  The `discard` button of a form's `submit` block, a LiveComponent on a page, driven the way an
  admin drives it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  It stands beside Save while the form holds changes and puts the form back to its starting values:
  an edit to the saved record, a create to the empty form. Nothing is saved, and a tabs form stays
  on its tab.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @discard ~s|#plan-form [data-role="gervaz-discard"]|

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path \\ "/plans") do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp change(view, values),
    do: view |> form(@form, %{"form" => values}) |> render_change()

  defp discard(view) do
    view |> element(@discard) |> render_click()
    render_async(view)
  end

  test "stands beside Save only while the form holds changes" do
    view = open()
    refute has_element?(view, @discard)

    change(view, %{"title" => "Kit"})

    assert has_element?(view, @discard, "Discard")
  end

  test "an edit goes back to the saved values" do
    plan = Ash.create!(PlanItem, %{title: "Kit", kind: :subscription, discount: 10})
    view = open("/plans?id=#{plan.id}")

    change(view, %{"title" => "Changed", "kind" => "one_time", "discount" => "50"})
    discard(view)

    assert has_element?(view, ~s|#{@form} input[name="form[title]"][value="Kit"]|)
    assert has_element?(view, ~s|#{@form} input[name="form[discount]"][value="10"]|)

    assert has_element?(
             view,
             ~s|#{@form} input[name="form[kind]"][value="subscription"][checked]|
           )

    refute has_element?(view, @discard)
    assert [%{title: "Kit", discount: 10}] = Ash.read!(PlanItem)
  end

  test "a create goes back to the empty form" do
    view = open()

    change(view, %{"title" => "Kit", "kind" => "subscription"})
    discard(view)

    refute has_element?(view, ~s|#{@form} input[name="form[title]"][value="Kit"]|)
    assert has_element?(view, ~s|#{@form} input[name="form[kind]"][value="one_time"][checked]|)
    refute has_element?(view, @discard)
    assert Ash.read!(PlanItem) == []
  end

  test "a tabs form stays on its tab" do
    view = open()
    view |> element(~s|[role="tab"][data-step="pricing"]|) |> render_click()

    change(view, %{"discount" => "5"})
    discard(view)

    assert has_element?(view, ~s|[role="tab"][data-step="pricing"][aria-selected="true"]|)
    assert has_element?(view, ~s|#{@form} [data-step="pricing"]:not([hidden])|)
  end
end
