defmodule MishkaGervaz.Form.Templates.StandardCustomFieldTypeRenderTest do
  @moduledoc """
  A field whose type is a module of its own is drawn by that module's `render/2`, with the field's
  input name, id and value in its assigns.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ColoredEntry

  defp render_form(form) do
    field = FormInfo.field(ColoredEntry, :color)

    state =
      build_state(static_opts: [fields: [field], groups: []], mode: :create, form: form)

    static = %{state.static | notices: []}

    render_component(&Standard.render/1, %{
      static: static,
      state: %{state | static: static},
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  defp with_params(params) do
    ColoredEntry
    |> AshPhoenix.Form.for_create(:create, as: "form")
    |> AshPhoenix.Form.validate(params)
    |> Phoenix.Component.to_form()
  end

  test "draws the field through its type module's render/2" do
    html = render_form(with_params(%{"color" => "#ff0000"}))

    [picker] =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(~s|[data-role="color-picker"]|)
      |> Enum.to_list()

    assert LazyHTML.attribute(picker, "type") == ["color"]
    assert LazyHTML.attribute(picker, "name") == ["form[color]"]
    assert LazyHTML.attribute(picker, "value") == ["#ff0000"]
  end

  test "and draws no text input in its place" do
    html = render_form(with_params(%{}))

    assert html
           |> LazyHTML.from_fragment()
           |> LazyHTML.query(~s|input[name="form[color]"][type="text"]|)
           |> Enum.to_list() == []
  end
end
