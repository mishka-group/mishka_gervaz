defmodule MishkaGervaz.Form.Templates.StandardNumberBoundsRenderTest do
  @moduledoc """
  A form's `:range` and `:number` field draws its input with the field's `min` and `max` and its
  `ui` `step`; a range with none runs from 0 to 100.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoFieldsForm

  defp render_input(changes) do
    field = Map.merge(FormInfo.field(AutoFieldsForm, :age), changes)

    state =
      build_state(
        static_opts: [fields: [field], groups: []],
        mode: :update,
        form: to_form(%{"age" => "30"}, as: :form)
      )

    static = %{state.static | notices: []}

    html =
      render_component(&Standard.render/1, %{
        static: static,
        state: %{state | static: static},
        ui: MishkaGervaz.UIAdapters.Tailwind,
        myself: nil,
        uploads: %{}
      })

    [input] = Regex.run(~r/<input[^>]*name="form\[age\]"[^>]*>/, html)
    input
  end

  test "a range runs from the field's min to its max in its step" do
    input = render_input(%{type: :range, min: 18, max: 65, ui: %{step: 5}})

    assert input =~ ~s(type="range")
    assert input =~ ~s(min="18")
    assert input =~ ~s(max="65")
    assert input =~ ~s(step="5")
  end

  test "a range with no min or max runs from 0 to 100" do
    input = render_input(%{type: :range, min: nil, max: nil})

    assert input =~ ~s(min="0")
    assert input =~ ~s(max="100")
  end

  test "a number input carries the field's min, max and step" do
    input = render_input(%{type: :number, min: 1, max: 9, ui: %{step: 2}})

    assert input =~ ~s(type="number")
    assert input =~ ~s(min="1")
    assert input =~ ~s(max="9")
    assert input =~ ~s(step="2")
  end
end
