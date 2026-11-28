defmodule MishkaGervaz.Form.Web.CancelLiveTest do
  @moduledoc """
  The `cancel` button of a form's `submit` block with no `on_cancel` hook, driven the way an admin
  drives it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  On an edit it throws away the changes: the form goes back to the record's saved values, stays on
  the record and on its tab, and nothing is saved. On a create it starts the form over empty.
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

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp change(view, values),
    do: view |> form(@form, %{"form" => values}) |> render_change()

  defp cancel(view) do
    view
    |> element(~s|#{@form} [data-role="gervaz-form-submit"] button|, "Cancel")
    |> render_click()

    render_async(view)
  end

  test "an edit goes back to the saved values and stays on the record and its tab" do
    plan = Ash.create!(PlanItem, %{title: "Kit", discount: 10})
    view = open("/plans?id=#{plan.id}")
    view |> element(~s|[role="tab"][data-step="pricing"]|) |> render_click()

    change(view, %{"title" => "Changed", "discount" => "50"})
    cancel(view)

    assert has_element?(view, ~s|#{@form} input[name="form[title]"][value="Kit"]|)
    assert has_element?(view, ~s|#{@form} input[name="form[discount]"][value="10"]|)
    assert view |> element("#pricing-extra") |> render() =~ "Priced as update"
    assert has_element?(view, ~s|[role="tab"][data-step="pricing"][aria-selected="true"]|)
    assert has_element?(view, ~s|#{@form} [data-step="pricing"]:not([hidden])|)
    assert has_element?(view, "#dirty", "false")
    assert [%{title: "Kit", discount: 10}] = Ash.read!(PlanItem)
  end

  test "a create starts over empty" do
    view = open("/plans")

    change(view, %{"title" => "Kit"})
    cancel(view)

    refute has_element?(view, ~s|#{@form} input[name="form[title]"][value="Kit"]|)
    assert view |> element("#pricing-extra") |> render() =~ "Priced as create"
    assert Ash.read!(PlanItem) == []
  end
end
