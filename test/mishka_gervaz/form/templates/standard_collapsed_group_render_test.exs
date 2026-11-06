defmodule MishkaGervaz.Form.Templates.StandardCollapsedGroupRenderTest do
  @moduledoc """
  A group declared `collapsed true` starts closed, as a `<details>` the reader opens by its label,
  whether or not it also says `collapsible true`; a collapsible group that is not collapsed starts
  open. The reader's choice survives a redraw (the `<details>` ignores the server's `open` once
  mounted), and a collapsed group opens by itself when one of its fields shows an error.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard

  defp render_form(settings, errors \\ %{}) do
    [general, settings_group] = default_groups()
    groups = [general, Map.merge(settings_group, settings)]

    state =
      build_state(
        static_opts: [groups: groups],
        mode: :create,
        form: to_form(%{}, as: :form),
        errors: errors
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

    html |> LazyHTML.from_fragment() |> LazyHTML.query(~s|[data-group="settings"]|)
  end

  defp details(group), do: LazyHTML.query(group, "details")

  defp open?(group), do: group |> details() |> LazyHTML.attribute("open") != []

  test "a collapsed group starts closed, collapsible or not" do
    for collapsible <- [true, false] do
      group = render_form(%{collapsed: true, collapsible: collapsible})

      assert group |> details() |> Enum.count() == 1
      refute open?(group)
      assert group |> LazyHTML.query("summary") |> LazyHTML.text() =~ "Settings"
    end
  end

  test "a collapsible group that is not collapsed starts open" do
    assert render_form(%{collapsed: false, collapsible: true}) |> open?()
  end

  test "the reader's open or closed choice survives a redraw" do
    [mounted] =
      %{collapsed: true}
      |> render_form()
      |> details()
      |> LazyHTML.attribute("phx-mounted")

    assert mounted =~ "ignore_attrs"
    assert mounted =~ "open"
  end

  test "a collapsed group opens when one of its fields shows an error" do
    closed = render_form(%{collapsed: true})
    assert LazyHTML.query(closed, ~s|span[hidden][phx-mounted]|) |> Enum.count() == 0

    failed = render_form(%{collapsed: true}, %{status: ["is invalid"]})

    [opener] =
      failed |> LazyHTML.query(~s|span[hidden][phx-mounted]|) |> LazyHTML.attribute("phx-mounted")

    assert opener =~ "set_attr"
    assert opener =~ "closest"
  end
end
