defmodule MishkaGervaz.Form.Web.StepMountLiveTest do
  @moduledoc """
  What a page chooses for a `:tabs` form's steps when it mounts it
  (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`): `navigation` takes
  the place of the resource's own, `step` opens the form on that step, and `notify_step` tells the
  page each step the form moves to, so a page that hands the step back keeps the form where it is.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Web.Live
  alias MishkaGervaz.Test.Web.{PlanItem, WizardItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @tabs ~s|#plan-form-wrapper [role="tablist"]|
  @next ~s|#plan-form [data-role="gervaz-step-next"]|
  @save ~s|#plan-form button[type="submit"]:not([data-role])|
  @user %{id: "master-1", site_id: nil, role: :admin}

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
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

  describe "navigation" do
    test "sequential over the resource's free tabs moves with Next and opens the visited tabs" do
      view = open("/plans?navigation=sequential")

      assert has_element?(view, @next)
      refute has_element?(view, @save)
      assert has_element?(view, ~s|#{@tabs} [role="tab"][data-step="pricing"][disabled]|)

      view |> form(@form, %{"form" => %{"title" => "Kit"}}) |> render_submit()

      assert shown_step(view) == ["pricing"]
      assert Ash.read!(PlanItem) == []
    end

    test "left out, the resource's own navigation stays" do
      view = open("/plans")

      assert has_element?(view, @save)
      refute has_element?(view, @next)
    end

    test "a value that is not a navigation, or free on a wizard, is refused" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}

      assert_raise ArgumentError, ~r/navigation/, fn ->
        Live.update(
          %{id: "plan", resource: PlanItem, current_user: @user, navigation: :sideways},
          socket
        )
      end

      assert_raise ArgumentError, ~r/navigation/, fn ->
        Live.update(
          %{id: "wizard", resource: WizardItem, current_user: @user, navigation: :free},
          socket
        )
      end
    end
  end

  describe "step" do
    test "opens the form on that tab" do
      view = open("/plans?step=pricing")

      assert shown_step(view) == ["pricing"]
      assert has_element?(view, ~s|#{@tabs} [role="tab"][aria-selected="true"]|, "Pricing")
    end

    test "a step the form has not opens it on its first tab" do
      view = open("/plans?step=nowhere")

      assert shown_step(view) == ["basics"]
    end

    test "with sequential navigation, the steps before it open as visited ones" do
      view = open("/plans?navigation=sequential&step=publishing")

      assert shown_step(view) == ["publishing"]
      refute has_element?(view, ~s|#{@tabs} [role="tab"][disabled]|)
      assert has_element?(view, @save)
    end
  end

  describe "notify_step" do
    test "tells the page each tab the form moves to, and the step handed back keeps it there" do
      view = open("/plans")
      assert view |> element("#step") |> render() =~ ~r|<p id="step">\s*</p>|

      view |> tab(:publishing) |> render_click()

      assert view |> element("#step") |> render() =~ "publishing"
      assert shown_step(view) == ["publishing"]

      view |> tab(:basics) |> render_click()

      assert view |> element("#step") |> render() =~ "basics"
      assert shown_step(view) == ["basics"]
    end

    test "says nothing while the form stays on its step" do
      view = open("/plans")

      view |> form(@form, %{"form" => %{"title" => "Kit"}}) |> render_change()

      assert view |> element("#step") |> render() =~ ~r|<p id="step">\s*</p>|
    end
  end
end
