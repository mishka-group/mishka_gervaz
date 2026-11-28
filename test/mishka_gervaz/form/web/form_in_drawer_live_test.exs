defmodule MishkaGervaz.Form.Web.FormInDrawerLiveTest do
  @moduledoc """
  A form in the Tailwind adapter's drawer, on a page that keeps the form's `{:form_dirty, …}`
  (`MishkaGervaz.Test.Web.PlanPageLive` on `/plans/drawer`).

  The drawer's close button and backdrop ask "Discard your changes?" only while the form holds
  changes, and Escape closes it only while it holds none. Its close runs the page's `close_drawer`,
  which takes it away. Its tabs and its submit row stay in view while its fields scroll.
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

  # The elements the drawer's open runs `focus_first` on, found in the page as the browser finds them.
  defp focused_on_open(view) do
    doc = view |> render() |> LazyHTML.from_fragment()
    [mounted] = doc |> LazyHTML.query("#plan-drawer") |> LazyHTML.attribute("phx-mounted")

    [selector] =
      for ["focus_first", %{"to" => to}] <- Jason.decode!(mounted), do: to

    doc |> LazyHTML.query(selector) |> LazyHTML.attribute("id")
  end

  test "the form stands in the drawer's panel" do
    view = open()

    assert has_element?(view, "#plan-drawer-panel[role=dialog] #plan-form")
    assert has_element?(view, "#plan-drawer-title", "Edit plan")
  end

  test "keeps its tabs at the top of the drawer's body and its submit row at the bottom" do
    view = open()
    doc = view |> render() |> LazyHTML.from_fragment()
    body = ~s|#plan-drawer-body[data-role="gervaz-panel-body"]|

    for {piece, inside, edge} <- [
          {"gervaz-form-steps", ~s|[role="tablist"]|, "top-0"},
          {"gervaz-form-submit", ~s|button[type="submit"]|, "bottom-0"}
        ] do
      selector = ~s|#{body} [data-role="#{piece}"]|
      assert has_element?(view, "#{selector} #{inside}")
      [class] = doc |> LazyHTML.query(selector) |> LazyHTML.attribute("class")
      assert class =~ "in-data-[role=gervaz-panel-body]:sticky"
      assert class =~ "in-data-[role=gervaz-panel-body]:#{edge} "
    end
  end

  test "opening it focuses the first field of the current tab, not the tab buttons above it" do
    view = open()

    assert focused_on_open(view) == ["plan-step-basics"]
    assert has_element?(view, "#plan-step-basics input")

    view |> element(~s|#plan-tab-publishing|) |> render_click()

    assert focused_on_open(view) == ["plan-step-publishing"]
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
