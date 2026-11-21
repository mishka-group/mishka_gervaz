defmodule MishkaGervaz.Form.Web.PutValuesLiveTest do
  @moduledoc """
  A page puts a value it worked out into a mounted form (`MishkaGervaz.Form.Web.Live.put_values/2`),
  driven on `MishkaGervaz.Test.Web.PlanPageLive`, whose `#put-discount` button puts a discount of
  15 into the form of `MishkaGervaz.Test.Web.PlanItem`.

  The value is in the form and in its save, what the reader typed into the other fields stays, the
  form is not counted as holding the reader's changes, a form still reading its record takes the
  value once it has read it, and a name the form has no field for is refused.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Form.Web.Live
  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @master %{id: "master-1", site_id: nil, role: :admin}

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path \\ "/plans") do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp put_discount(view), do: view |> element("#put-discount") |> render_click()

  test "the value is in the form and in the save, and what was typed stays" do
    view = open()
    view |> form(@form, %{"form" => %{"title" => "Gold"}}) |> render_change()

    put_discount(view)

    assert has_element?(view, ~s|#{@form} input[name="form[discount]"][value="15"]|)
    assert has_element?(view, ~s|#{@form} input[name="form[title]"][value="Gold"]|)

    view |> form(@form) |> render_submit()

    assert has_element?(view, "#saved", "Gold")
    assert [%PlanItem{title: "Gold", discount: 15}] = Ash.read!(PlanItem)
  end

  test "a value the page put is not a change the reader made" do
    view = open()

    put_discount(view)

    assert has_element?(view, ~s|#{@form} input[name="form[discount]"][value="15"]|)
    assert has_element?(view, "#dirty", "false")
  end

  test "an edit takes the value and keeps the record's own values" do
    plan = Ash.create!(PlanItem, %{title: "Kit", discount: 5})
    view = open("/plans?id=#{plan.id}")

    put_discount(view)
    view |> form(@form) |> render_submit()

    assert %PlanItem{title: "Kit", discount: 15} = Ash.get!(PlanItem, plan.id)
  end

  describe "the component" do
    defp mounted(assigns) do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, flash: %{}},
        transport_pid: self()
      }

      {:ok, socket} =
        Live.update(
          Map.merge(%{id: "plan", resource: PlanItem, current_user: @master}, assigns),
          socket
        )

      socket
    end

    test "a form still reading its record takes the values once it has read it" do
      plan = Ash.create!(PlanItem, %{title: "Kit", discount: 5})
      socket = mounted(%{record_id: plan.id})
      assert socket.assigns.form_state.form == nil

      {:ok, socket} = Live.update(%{id: "plan", put_values: %{"discount" => 15}}, socket)
      assert socket.assigns.form_state.form == nil

      {:ok, form} =
        RecordLoader.Default.load_for_edit(socket.assigns.form_state, plan.id, actor: @master)

      {:noreply, socket} = Live.handle_async(:load_record, {:ok, {:ok, form}}, socket)

      form = socket.assigns.form_state.form
      assert Phoenix.HTML.Form.input_value(form, :discount) == 15
      assert Phoenix.HTML.Form.input_value(form, :title) == "Kit"
    end

    test "a name the form has no field for is refused" do
      socket = mounted(%{})

      assert_raise ArgumentError, ~r/has no field :nope/, fn ->
        Live.update(%{id: "plan", put_values: %{nope: 1}}, socket)
      end
    end
  end
end
