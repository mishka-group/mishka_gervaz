defmodule MishkaGervaz.Form.Templates.StandardSelectPromptRenderTest do
  @moduledoc """
  A form's `:select` draws an empty choice ahead of its options by the field alone: none for a
  required field or one with a default, "Select..." for an optional one, the `ui placeholder`
  when it is set. It never draws the filter's "All".
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.AutoFieldsForm

  defp render_select(changes) do
    field =
      %{FormInfo.field(AutoFieldsForm, :birthday) | type: :select}
      |> Map.put(:options, [{"Draft", "draft"}, {"Alpha", "alpha"}])
      |> Map.merge(changes)

    state =
      build_state(
        static_opts: [fields: [field], groups: []],
        mode: :create,
        form: to_form(%{}, as: :form)
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

  defp blank_option?(html), do: html =~ ~s(<option value="">)

  test "a required select has no empty choice" do
    html = render_select(%{required: true})

    refute blank_option?(html)
    refute html =~ ">All<"
    assert html =~ ~s(<option value="draft")
  end

  test "a select with a default has no empty choice" do
    html = render_select(%{required: false, default: "draft"})

    refute blank_option?(html)
    refute html =~ ">All<"
  end

  test "an optional select has a neutral empty choice, not All" do
    html = render_select(%{required: false})

    assert html =~ ~r/<option value="">\s*Select\.\.\.\s*<\/option>/
    refute html =~ ">All<"
  end

  test "a ui placeholder labels the empty choice, required or not" do
    for required <- [true, false] do
      html =
        render_select(%{
          required: required,
          ui: %{placeholder: "Pick a status", label: nil, description: nil, extra: %{}}
        })

      assert html =~ ~r/<option value="">\s*Pick a status\s*<\/option>/
      refute html =~ ">All<"
    end
  end
end
