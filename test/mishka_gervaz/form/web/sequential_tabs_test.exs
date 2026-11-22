defmodule MishkaGervaz.Form.Web.SequentialTabsTest do
  @moduledoc """
  A `:tabs` form whose steps open in order (`navigation :sequential`): its tabs open only the steps
  already visited, Back and Next move it, and Save stands on the last tab alone, as on a wizard.
  The form is `MishkaGervaz.Test.Web.PlanItem`'s, switched to `:sequential`.
  """
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{Events, Live, Renderer}
  alias MishkaGervaz.Test.Web.PlanItem

  @user %{id: "master-1", site_id: nil, role: :admin}

  defp sequential do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} = Live.update(%{id: "plan", resource: PlanItem, current_user: @user}, socket)

    Phoenix.Component.update(socket, :form_state, fn state ->
      %{state | static: %{state.static | layout_navigation: :sequential}}
    end)
  end

  defp html(socket) do
    html = render_component(&Renderer.render/1, %{form_state: socket.assigns.form_state})
    LazyHTML.from_fragment(html)
  end

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  test "a tab not yet visited is disabled" do
    doc = html(sequential())

    assert count(doc, ~s|[role="tab"][data-step="basics"]:not([disabled])|) == 1
    assert count(doc, ~s|[role="tab"][data-step="pricing"][disabled]|) == 1
    assert count(doc, ~s|[role="tab"][data-step="publishing"][disabled]|) == 1
  end

  test "goto_step to a tab not yet visited stays where it is" do
    socket = sequential()
    {:noreply, socket} = Events.handle("goto_step", %{"step" => "publishing"}, socket)

    assert socket.assigns.form_state.current_step == :basics
  end

  test "Next stands where Save does on a wizard, and a save moves on before the last tab" do
    socket = sequential()
    doc = html(socket)

    assert count(doc, ~s|[data-role="gervaz-step-next"]|) == 1
    assert count(doc, ~s|button[type="submit"]:not([data-role])|) == 0

    {:noreply, socket} = Events.handle("save", %{"form" => %{"title" => "Kit"}}, socket)

    assert socket.assigns.form_state.current_step == :pricing
    assert Ash.read!(PlanItem) == []
    assert count(html(socket), ~s|[role="tab"][data-step="basics"]:not([disabled])|) == 1
  end
end
