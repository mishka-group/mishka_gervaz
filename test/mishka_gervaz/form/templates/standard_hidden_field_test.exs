defmodule MishkaGervaz.Form.Templates.StandardHiddenFieldTest do
  @moduledoc """
  A `:hidden` field is drawn as a bare `<input type="hidden">` carrying its value: no label, no
  text box, nothing a reader sees, and the save still sends it.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost

  test "a hidden field is a hidden input with its value and no label" do
    field = FormPost |> FormInfo.field(:title) |> Map.put(:type, :hidden)

    state =
      build_state(
        static_opts: [id: "post", fields: [field], groups: []],
        mode: :create,
        form: to_form(%{"title" => "kept"}, as: :form, id: "post-form")
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

    doc = LazyHTML.from_fragment(html)

    assert [input] = doc |> LazyHTML.query("input[name='form[title]']") |> Enum.to_list()
    assert LazyHTML.attribute(input, "type") == ["hidden"]
    assert LazyHTML.attribute(input, "value") == ["kept"]
    assert doc |> LazyHTML.query("label[for='post-form_title']") |> Enum.count() == 0
    refute html =~ ~s(type="text")
  end
end
