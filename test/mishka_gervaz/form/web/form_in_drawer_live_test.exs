defmodule MishkaGervaz.Form.Web.FormInDrawerLiveTest do
  @moduledoc """
  A form in the Tailwind adapter's drawer, on a page that keeps the form's `{:form_dirty, …}`
  (`MishkaGervaz.Test.Web.PlanPageLive` on `/plans/drawer`).

  The drawer's close button and backdrop ask "Discard your changes?" only while the form holds
  changes, and Escape closes it only while it holds none. Its close runs the page's `close_drawer`,
  which takes it away.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @close ~s|#plan-drawer [data-role="gervaz-panel-close"]|
  @question "Discard your changes?"

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/plans/drawer")
    render_async(view)
    view
  end

  test "the form stands in the drawer's panel" do
    view = open()

    assert has_element?(view, "#plan-drawer-panel[role=dialog] #plan-form")
    assert has_element?(view, "#plan-drawer-title", "Edit plan")
  end

  test "asks before it closes only while the form holds changes" do
    view = open()
    refute has_element?(view, "#{@close}[data-confirm]")
    assert has_element?(view, "#plan-drawer-panel[phx-window-keydown]")

    view |> form("#plan-form", %{"form" => %{"title" => "Kit"}}) |> render_change()

    assert has_element?(view, ~s|#{@close}[data-confirm="#{@question}"]|)
    assert has_element?(view, ~s|#plan-drawer-backdrop[data-confirm="#{@question}"]|)
    refute has_element?(view, "#plan-drawer-panel[phx-window-keydown]")
  end

  test "its close runs the page's close_drawer, which takes it away" do
    view = open()

    view |> element(@close) |> render_click()

    refute has_element?(view, "#plan-drawer")
  end
end
