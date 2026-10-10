defmodule MishkaGervaz.Form.Templates.StandardGroupGridRenderTest do
  @moduledoc """
  A form's groups and the form itself lay their fields out in columns that never grow past the
  form: one column below the breakpoint, the group's columns above it, each `minmax(0, 1fr)`
  (`grid-cols-*`), and every group's `<fieldset>` without the browser's `min-width: min-content`.
  A field holding something wide — a row of folders, a long address — scrolls inside its column
  instead of pushing the form out of a modal.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard

  defp render_form(groups, layout_columns) do
    state =
      build_state(
        static_opts: [groups: groups, layout_columns: layout_columns],
        mode: :create,
        form: to_form(%{}, as: :form)
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

  defp grids(html), do: Regex.scan(~r/class="(grid [^"]*)"/, html, capture: :all_but_first)

  test "every grid of fields is one shrinking column below its breakpoint" do
    two_columns =
      Enum.map(default_groups(), &Map.put(&1, :ui, %{columns: 2}))

    for {groups, columns} <- [{default_groups(), 1}, {two_columns, 2}, {[], 2}] do
      found = groups |> render_form(columns) |> grids()

      assert found != []

      assert Enum.all?(found, fn [class] -> class =~ ~r/(^| )grid-cols-1( |$)/ end),
             inspect(found)
    end
  end

  test "a group's fieldset does not grow to what it holds" do
    html = render_form(default_groups(), 1)

    assert [_ | _] = fieldsets = Regex.scan(~r/<fieldset[^>]*>/, html)
    assert Enum.all?(fieldsets, fn [tag] -> tag =~ ~r/class="min-w-0/ end)
  end
end
