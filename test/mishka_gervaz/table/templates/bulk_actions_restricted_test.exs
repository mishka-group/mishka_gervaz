defmodule MishkaGervaz.Table.Templates.BulkActionsRestrictedTest do
  @moduledoc """
  A restricted bulk action is drawn for a master only: a state that does not say the user is a
  master gets none.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared

  defp render_bar(state_extra) do
    action = %{name: :purge, restricted: true, visible: nil, ui: nil, confirm: nil}

    assigns = %{
      __changed__: nil,
      myself: nil,
      static: %{
        id: "bulk-test",
        bulk_actions: [action],
        ui_adapter: MishkaGervaz.UIAdapters.Tailwind
      },
      state:
        Map.merge(
          %{
            selected_ids: MapSet.new(["1"]),
            excluded_ids: MapSet.new(),
            select_all?: false,
            archive_status: :active
          },
          state_extra
        )
    }

    rendered_to_string(Shared.render_bulk_actions(assigns))
  end

  test "a master sees the restricted action" do
    assert render_bar(%{master_user?: true}) =~ ~s(phx-value-action="purge")
  end

  test "a user who is not a master does not" do
    refute render_bar(%{master_user?: false}) =~ ~s(phx-value-action="purge")
  end

  test "a state that does not say the user is a master does not" do
    refute render_bar(%{}) =~ ~s(phx-value-action="purge")
    refute render_bar(%{master_user?: nil}) =~ ~s(phx-value-action="purge")
  end
end
