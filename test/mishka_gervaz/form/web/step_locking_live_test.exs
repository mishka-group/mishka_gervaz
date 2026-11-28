defmodule MishkaGervaz.Form.Web.StepLockingLiveTest do
  @moduledoc """
  Which tabs of a `:tabs` form whose steps open in order (`navigation :sequential`) a reader may
  open once the record is saved: every one, however the form is opened and wherever it moves
  (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @tabs ~s|#plan-form-wrapper [role="tablist"]|
  @next ~s|#plan-form [data-role="gervaz-step-next"]|

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    %{plan: Ash.create!(PlanItem, %{title: "Kit"})}
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp disabled_tabs(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{@tabs} [role="tab"][disabled]|)
    |> LazyHTML.attribute("data-step")
  end

  test "a saved record opened on its first step keeps every tab open", %{plan: plan} do
    view = open("/plans?id=#{plan.id}&navigation=sequential&step=basics")

    assert disabled_tabs(view) == []
  end

  test "a saved record opened with no step keeps every tab open", %{plan: plan} do
    view = open("/plans?id=#{plan.id}&navigation=sequential")

    assert disabled_tabs(view) == []
  end

  test "Next after a jump back to an earlier tab keeps the later tabs open", %{plan: plan} do
    view = open("/plans?id=#{plan.id}&navigation=sequential&step=publishing")

    view |> element(~s|#{@tabs} [role="tab"][data-step="basics"]|) |> render_click()
    assert has_element?(view, @next)
    view |> form(@form, %{"form" => %{"title" => "Kit"}}) |> render_submit()

    assert disabled_tabs(view) == []
  end

  test "a tab of a later step opens on a saved record", %{plan: plan} do
    view = open("/plans?id=#{plan.id}&navigation=sequential&step=basics")

    view |> element(~s|#{@tabs} [role="tab"][data-step="publishing"]|) |> render_click()

    assert has_element?(
             view,
             ~s|#{@tabs} [role="tab"][data-step="publishing"][aria-selected="true"]|
           )
  end
end
