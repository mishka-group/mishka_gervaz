defmodule MishkaGervaz.Form.Templates.StandardSelectStateOptionsRenderTest do
  @moduledoc """
  A form's `:select` whose `options` is `fn state -> options end` draws the options the function
  gives for the form state it is drawn with, so they follow what the form holds.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoFieldsForm

  defp languages(%{form: %{params: %{"kind" => "page"}}}),
    do: [{"English", "en"}, {"Page language", "page"}]

  defp languages(_state), do: [{"English", "en"}]

  defp render_select(type, params) do
    field =
      %{FormInfo.field(AutoFieldsForm, :birthday) | type: type}
      |> Map.put(:options, &languages/1)

    state =
      build_state(
        static_opts: [fields: [field], groups: []],
        mode: :create,
        form: to_form(params, as: :form)
      )

    static = %{state.static | notices: []}

    render_component(&Standard.render/1, %{
      static: static,
      state: %{state | static: static},
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  test "a select draws the options its function gives for the form state" do
    html = render_select(:select, %{})

    assert html =~ ~s(<option value="en">English</option>)
    refute html =~ "Page language"

    assert render_select(:select, %{"kind" => "page"}) =~
             ~s(<option value="page">Page language</option>)
  end
end
