defmodule MishkaGervaz.Table.Templates.BulkConfirmCountTest do
  @moduledoc """
  `{count}` in a bulk action's `confirm` becomes the number of rows the action runs on: the checked
  rows, or with select all the table's total minus the unchecked rows. A table that cannot tell
  the total leaves `{count}` as written.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared

  @confirm "Delete {count} rows?"

  defp state(extra) do
    Map.merge(
      %{
        selected_ids: MapSet.new(),
        excluded_ids: MapSet.new(),
        select_all?: false,
        archive_status: :active,
        master_user?: true,
        total_count: nil,
        total_pages: nil,
        has_more?: false
      },
      extra
    )
  end

  defp ids(count), do: MapSet.new(Enum.map(1..count//1, &"id-#{&1}"))

  defp render_bar(state_extra, confirm \\ @confirm) do
    action = %{name: :purge, restricted: false, visible: nil, ui: nil, confirm: confirm}

    assigns = %{
      __changed__: nil,
      myself: nil,
      static: %{
        id: "bulk-test",
        bulk_actions: [action],
        ui_adapter: MishkaGervaz.UIAdapters.Tailwind
      },
      state: state(state_extra)
    }

    rendered_to_string(Shared.render_bulk_actions(assigns))
  end

  defp confirm_of(html) do
    case Regex.run(~r/data-confirm="([^"]*)"/, html, capture: :all_but_first) do
      [text] -> text
      nil -> nil
    end
  end

  describe "bulk_selection_count/1" do
    test "counts the checked rows" do
      assert Shared.bulk_selection_count(state(%{selected_ids: ids(3)})) == 3
      assert Shared.bulk_selection_count(state(%{})) == 0
    end

    test "with select all, is the counted total minus the unchecked rows" do
      state = state(%{select_all?: true, total_count: 120, total_pages: 6, excluded_ids: ids(5)})

      assert Shared.bulk_selection_count(state) == 115
    end

    test "with select all, never goes below zero" do
      state = state(%{select_all?: true, total_count: 2, total_pages: 1, excluded_ids: ids(5)})

      assert Shared.bulk_selection_count(state) == 0
    end

    test "with select all, is the loaded rows once every row is loaded" do
      state = state(%{select_all?: true, total_count: 12, has_more?: false})

      assert Shared.bulk_selection_count(state) == 12
    end

    test "with select all, is nil while rows are left to load and the table does not count" do
      assert Shared.bulk_selection_count(
               state(%{select_all?: true, total_count: 20, has_more?: true})
             ) == nil

      assert Shared.bulk_selection_count(state(%{select_all?: true})) == nil
    end
  end

  describe "the confirm of a bulk action button" do
    test "names the checked rows" do
      assert confirm_of(render_bar(%{selected_ids: ids(3)})) == "Delete 3 rows?"
    end

    test "names every row but the unchecked ones with select all" do
      html =
        render_bar(%{select_all?: true, total_count: 120, total_pages: 6, excluded_ids: ids(5)})

      assert confirm_of(html) == "Delete 115 rows?"
    end

    test "keeps {count} when select all runs on a total the table does not know" do
      html = render_bar(%{select_all?: true, total_count: 20, has_more?: true})

      assert confirm_of(html) == @confirm
    end

    test "fills every {count} of the text" do
      html = render_bar(%{selected_ids: ids(2)}, "{count} of {count} rows")

      assert confirm_of(html) == "2 of 2 rows"
    end

    test "leaves a confirm with no {count} as written" do
      assert confirm_of(render_bar(%{selected_ids: ids(2)}, "Sure?")) == "Sure?"
    end

    test "draws no confirm when the action has none" do
      refute render_bar(%{selected_ids: ids(2)}, nil) =~ "data-confirm"
    end
  end
end
