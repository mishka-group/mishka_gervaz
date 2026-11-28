defmodule MishkaGervaz.Form.Web.InStepSlotLiveTest do
  @moduledoc """
  A page's own markup in one step of a `:tabs` form, through the form's `:in_step` slot
  (`MishkaGervaz.Test.Web.PlanPageLive`, whose slot adds `#pricing-extra` to the Pricing tab).

  The slot is drawn in its step's panel after the step's groups, in that step only, inside the one
  `<form>`, and is given the form as the `:body` slot is. A slot naming a step the form has not
  raises.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Web.{Live, Renderer}
  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @user %{id: "master-1", site_id: nil, role: :admin}

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp count(view, selector),
    do: view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()

  test "draws in its own step's panel, after the step's groups, inside the form" do
    view = open("/plans")

    assert count(view, "#plan-form #plan-step-pricing > #pricing-extra:last-child") == 1
    assert count(view, "#pricing-extra") == 1
    assert count(view, "#plan-step-basics #pricing-extra") == 0
    assert count(view, "#plan-step-publishing #pricing-extra") == 0
  end

  test "is given the form" do
    view = open("/plans")
    assert view |> element("#pricing-extra") |> render() =~ "Priced as create"

    record = Ash.create!(PlanItem, %{title: "Kit"})
    view = open("/plans?id=#{record.id}")
    assert view |> element("#pricing-extra") |> render() =~ "Priced as update"
  end

  test "shows with its step: hidden on another tab, shown on its own" do
    view = open("/plans")
    assert count(view, "#plan-step-pricing[hidden] #pricing-extra") == 1

    view |> element(~s|[role="tab"][data-step="pricing"]|) |> render_click()
    assert count(view, "#plan-step-pricing:not([hidden]) #pricing-extra") == 1
  end

  test "a slot naming a step the form has not raises" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} = Live.update(%{id: "plan", resource: PlanItem, current_user: @user}, socket)
    state = %{socket.assigns.form_state | loading: :loaded}
    state = MishkaGervaz.Form.Web.DataLoader.new_record(socket, state).assigns.form_state

    slot = [%{__slot__: :in_step, name: :nowhere, inner_block: fn _changed, _form -> "x" end}]

    assert_raise ArgumentError, ~r/nowhere/, fn ->
      render_component(&Renderer.render/1, %{form_state: state, in_step: slot})
    end
  end
end
