defmodule MishkaGervaz.Form.Templates.StandardCalendarRenderTest do
  @moduledoc """
  A form's `:date` and `:datetime` field is the calendar the form draws: the value in a hidden
  input of the field's name, a button that opens it, and — once open — the month and year it shows,
  which the `picker_*` events of `MishkaGervaz.Form.Web.Events` move.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoFieldsForm

  defp render_form(type, value, pickers) do
    field = %{FormInfo.field(AutoFieldsForm, :birthday) | type: type}

    state =
      build_state(
        static_opts: [fields: [field], groups: []],
        mode: :update,
        form: to_form(%{"birthday" => value}, as: :form)
      )

    static = %{state.static | notices: []}
    state = %{state | static: static, pickers: pickers}

    render_component(&Standard.render/1, %{
      static: static,
      state: state,
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  test "a date field is a closed calendar holding its value" do
    html = render_form(:date, "2024-09-09", %{})

    assert html =~ ~r/<input type="hidden" name="form\[birthday\]" value="2024-09-09"/
    assert html =~ ~s(phx-click=)
    assert html =~ "picker_open"
    refute html =~ ~s(type="date")
    refute html =~ ~s(id="form_birthday-month")
  end

  test "open, it shows the month the state holds" do
    html = render_form(:date, "2024-09-09", %{birthday: ~D[2023-02-01]})

    assert html =~ ~r/id="form_birthday-month"[^>]*>\s*February 2023\s*</
    assert html =~ ~s(id="form_birthday-day-2023-02-28")
  end

  test "a date and time field has the hour and the minute" do
    html = render_form(:datetime, "2024-09-09T22:45:00", %{birthday: ~D[2024-09-01]})

    assert html =~ ~r/<input type="hidden" name="form\[birthday\]" value="2024-09-09T22:45:00"/
    assert html =~ ~s(name="_gvz_picker[birthday][hour]")
    assert html =~ ~s(name="_gvz_picker[birthday][minute]")
  end
end
