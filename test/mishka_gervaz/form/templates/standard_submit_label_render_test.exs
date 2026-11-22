defmodule MishkaGervaz.Form.Templates.StandardSubmitLabelRenderTest do
  @moduledoc """
  A submit button named by the form state: one form that a page mounts for several actions (pause,
  resume, end) reads its button from the mount's `defaults`, so the button says what it does.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard

  defp render_with(label, defaults) do
    state =
      build_state(
        static_opts: [
          fields: [],
          groups: [],
          submit: %{
            create: %{label: label, disabled: false, restricted: false, visible: true},
            position: :bottom
          }
        ],
        mode: :create,
        form: to_form(%{}, as: :form),
        defaults: defaults
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

  test "a label may be a function of the form state" do
    label = fn state -> if state.defaults[:action] == :pause, do: "Pause", else: "End now" end

    assert render_with(label, %{action: :pause}) =~ "Pause"
    assert render_with(label, %{action: :end_now}) =~ "End now"
  end

  test "a string and a function of no arguments still read as they did" do
    assert render_with("Save the rules", nil) =~ "Save the rules"
    assert render_with(fn -> "Send" end, nil) =~ "Send"
  end
end
