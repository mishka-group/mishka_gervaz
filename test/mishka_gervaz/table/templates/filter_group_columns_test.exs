defmodule MishkaGervaz.Table.Templates.FilterGroupColumnsTest do
  @moduledoc """
  The grid of a collapsible filter group is set by `columns` in the group's `ui` block, and is 3
  columns when the block sets none.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  defp render_advanced_group(ui_columns) do
    state =
      "posts"
      |> State.init(ComplexTestResource, %{id: "user-1", role: :admin})
      |> State.update(loading: :loaded, has_initial_data?: true)

    groups =
      Enum.map(state.static.filter_groups, fn
        %{name: :advanced} = group -> %{group | ui: %{group.ui | columns: ui_columns}}
        group -> group
      end)

    state = %{state | static: %{state.static | filter_groups: groups}}

    render_component(&Shared.render_filters/1, %{
      static: state.static,
      state: state,
      myself: nil,
      __changed__: %{}
    })
  end

  defp group_grid(html) do
    [classes] =
      Regex.run(~r/id="posts-filter-group-advanced".*?<div class="([^"]*grid[^"]*)"/s, html,
        capture: :all_but_first
      )

    classes |> String.split() |> Enum.filter(&String.match?(&1, ~r/^grid-cols-\d$/))
  end

  test "the ui columns of a group set its grid" do
    assert group_grid(render_advanced_group(2)) == ["grid-cols-2"]
    assert group_grid(render_advanced_group(5)) == ["grid-cols-5"]
  end

  test "a group whose ui sets no columns draws 3" do
    assert group_grid(render_advanced_group(nil)) == ["grid-cols-3"]
  end
end
