defmodule MishkaGervaz.Form.Templates.StandardNoticePositionRenderTest do
  @moduledoc """
  A notice at `:before_fields` is drawn before the fields no group holds: every field of a form
  without groups, or the fields a grouped form leaves out of its groups.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Entities.Notice
  alias MishkaGervaz.Form.Templates.Standard

  @notice struct(Notice, name: :heads_up, position: :before_fields, title: "Heads up first")

  defp render_form(groups) do
    state =
      build_state(
        static_opts: [groups: groups],
        mode: :create,
        form: to_form(%{}, as: :form)
      )

    static = %{state.static | notices: [@notice]}

    render_component(&Standard.render/1, %{
      static: static,
      state: %{state | static: static},
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  defp position_of(html, text) do
    case :binary.match(html, text) do
      {at, _length} -> at
      :nomatch -> nil
    end
  end

  test "on a form without groups, is drawn before its fields" do
    html = render_form([])

    assert notice_at = position_of(html, "Heads up first")
    assert notice_at < position_of(html, ~s|name="form[title]"|)
  end

  test "on a grouped form, is drawn before the fields no group holds, after the groups" do
    groups = Enum.take(default_groups(), 1)
    html = render_form(groups)

    assert notice_at = position_of(html, "Heads up first")
    assert position_of(html, ~s|name="form[content]"|) < notice_at
    assert notice_at < position_of(html, ~s|name="form[status]"|)
  end
end
