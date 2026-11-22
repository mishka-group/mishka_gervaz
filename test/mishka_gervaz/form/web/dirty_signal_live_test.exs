defmodule MishkaGervaz.Form.Web.DirtySignalLiveTest do
  @moduledoc """
  A form mounted with `notify_dirty`, a LiveComponent on a page, driven the way an admin drives it
  (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  The form tells its page `{:form_dirty, id, dirty?}` when it comes to hold changes and when it holds
  none any more: after a save or a Discard. Its wrapper carries `data-dirty`. Its Cancel and Discard,
  declared with `confirm`, carry the question in `data-confirm` while it holds changes, and only
  then.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @question "Discard your changes?"

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

  test "the page is told when the form comes to hold changes and when it holds none" do
    view = open()
    assert has_element?(view, "#dirty", "false")
    assert has_element?(view, ~s|#plan-form-wrapper[data-dirty="false"]|)

    change(view, %{"title" => "Kit"})

    assert has_element?(view, "#dirty", "true")
    assert has_element?(view, ~s|#plan-form-wrapper[data-dirty="true"]|)

    view |> element(~s|#{@form} [data-role="gervaz-discard"]|) |> render_click()
    render_async(view)

    assert has_element?(view, "#dirty", "false")
  end

  test "a save holds no changes any more" do
    view = open()
    change(view, %{"title" => "Kit"})

    view |> form(@form, %{"form" => %{"title" => "Kit"}}) |> render_submit()

    assert has_element?(view, "#saved", "Kit")
    assert has_element?(view, "#dirty", "false")
  end

  test "Cancel and Discard ask their question only while the form holds changes" do
    plan = Ash.create!(PlanItem, %{title: "Kit"})
    view = open("/plans?id=#{plan.id}")

    assert has_element?(view, ~s|#{@form} button[phx-click]:not([data-confirm])|, "Cancel")

    change(view, %{"title" => "Changed"})

    assert has_element?(view, ~s|#{@form} button[data-confirm="#{@question}"]|, "Cancel")

    assert has_element?(
             view,
             ~s|#{@form} [data-role="gervaz-discard"][data-confirm="#{@question}"]|
           )

    refute has_element?(view, ~s|#{@form} button[type="submit"][data-confirm]|)
  end

  describe "the message" do
    defp mounted(assigns) do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, flash: %{}},
        transport_pid: self()
      }

      base = %{
        id: "plan",
        resource: PlanItem,
        current_user: %{id: "m", site_id: nil, role: :admin}
      }

      {:ok, socket} = MishkaGervaz.Form.Web.Live.update(Map.merge(base, assigns), socket)
      socket
    end

    test "is sent once per change of state, to the page's process" do
      socket = mounted(%{notify_dirty: true})

      {:noreply, socket} =
        MishkaGervaz.Form.Web.Live.handle_event(
          "validate",
          %{"form" => %{"title" => "K"}},
          socket
        )

      assert_received {:form_dirty, "plan", true}

      {:noreply, _socket} =
        MishkaGervaz.Form.Web.Live.handle_event(
          "validate",
          %{"form" => %{"title" => "Ki"}},
          socket
        )

      refute_received {:form_dirty, _id, _dirty?}
    end

    test "is not sent to a page that did not ask for it" do
      socket = mounted(%{})

      {:noreply, _socket} =
        MishkaGervaz.Form.Web.Live.handle_event(
          "validate",
          %{"form" => %{"title" => "K"}},
          socket
        )

      refute_received {:form_dirty, _id, _dirty?}
    end
  end
end
