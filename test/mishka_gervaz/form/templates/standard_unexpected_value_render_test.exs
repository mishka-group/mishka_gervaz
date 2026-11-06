defmodule MishkaGervaz.Form.Templates.StandardUnexpectedValueRenderTest do
  @moduledoc """
  A field that holds one value draws as empty, and never crashes the form, when its params carry a
  map or a list instead, as a page drawn by an older form that had keys under the field sends.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoFieldsForm

  defp render_field(type, value, changes \\ %{}) do
    field =
      %{FormInfo.field(AutoFieldsForm, :birthday) | type: type}
      |> Map.merge(changes)

    state =
      build_state(
        static_opts: [fields: [field], groups: []],
        mode: :create,
        form: to_form(%{"birthday" => value}, as: :form)
      )

    static = %{state.static | notices: []}
    state = %{state | static: static}

    render_component(&Standard.render/1, %{
      static: static,
      state: state,
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  test "a select given a map or a list has none of its options chosen" do
    for value <- [%{"one_language" => "", "_unused_one_language" => ""}, ["draft"]] do
      html =
        render_field(:select, value, %{
          required: false,
          options: [{"Draft", "draft"}, {"Alpha", "alpha"}]
        })

      assert html =~ ~s(<option value="draft")
      refute html =~ "selected"
    end
  end

  test "a text input given a map or a list is empty" do
    for type <- [:text, :textarea, :number], value <- [%{"one" => "x"}, ["x"]] do
      html = render_field(type, value)

      assert html =~ ~s(name="form[birthday]")
      refute html =~ ~s(value="x")
    end
  end

  test "a select still shows the value it holds" do
    html =
      render_field(:select, "alpha", %{
        required: false,
        options: [{"Draft", "draft"}, {"Alpha", "alpha"}]
      })

    assert html =~ ~r/<option value="alpha" selected/
  end
end
