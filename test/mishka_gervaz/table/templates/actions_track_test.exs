defmodule MishkaGervaz.Table.Templates.ActionsTrackTest do
  @moduledoc """
  The Actions column is as wide as the most controls one row can draw, the header and every row
  share that track, and a table wider than its frame shows a scrollbar to reach the rest.

  Each control is a 30px square, 4px from the next, inside 16px of padding on either side: three
  of them need 130px, which a fixed 120px track cut off. Each one dims while its click is pending.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.TranslatedDsl

  @admin %{id: "user-1", role: :admin}
  @record %{id: "row-1", title: "Cat", slug: "cat", status: :published, featured: true}

  defp table_state(updates \\ []) do
    "actions-track"
    |> State.init(TranslatedDsl, @admin)
    |> State.update(Keyword.merge([loading: :loaded, has_initial_data?: true], updates))
  end

  # Only the three inline actions, without the layout that adds the "More" dropdown.
  defp three_buttons(state) do
    static = %{state.static | row_actions_layout: nil, row_action_dropdowns: []}
    %{state | static: static}
  end

  defp render_table(state) do
    stream_name = state.static.stream_name

    render_component(&TableTemplate.render/1, %{
      static: state.static,
      state: state,
      stream: [{"#{stream_name}-1", @record}],
      streams: %{stream_name => []},
      empty?: false,
      myself: nil,
      __changed__: %{}
    })
  end

  defp header_tracks(html, state) do
    [_, tracks] =
      Regex.run(
        ~r/id="#{state.static.stream_name}-thead"[^>]*style="grid-template-columns: ([^"]*);"/,
        html
      )

    tracks
  end

  defp row_tracks(html) do
    [_, tracks] =
      Regex.run(~r/class="gervaz-row grid[^"]*"\s+style="grid-template-columns: ([^"]*);"/, html)

    tracks
  end

  defp frame_class(html) do
    [_, class] = Regex.run(~r/data-role="gervaz-table-frame"\s+class="([^"]*)"/, html)
    class
  end

  defp action(name, opts \\ []), do: Map.merge(%{name: name, type: :event}, Map.new(opts))

  defp static_with(actions, opts \\ []) do
    %{
      row_actions: actions,
      row_action_dropdowns: Keyword.get(opts, :dropdowns, []),
      row_actions_layout: Keyword.get(opts, :layout)
    }
  end

  defp state_with(opts \\ []) do
    %{
      archive_status: Keyword.get(opts, :archive_status, :active),
      master_user?: Keyword.get(opts, :master_user?, true)
    }
  end

  describe "the Actions track" do
    test "fits three buttons with their padding, instead of a fixed 120px" do
      state = table_state() |> three_buttons()
      html = render_table(state)

      assert String.ends_with?(header_tracks(html, state), " minmax(130px,max-content)")
      refute header_tracks(html, state) =~ "120px"
    end

    test "grows with each control a row can draw, a dropdown's trigger included" do
      state = table_state()
      html = render_table(state)

      assert String.ends_with?(header_tracks(html, state), " minmax(164px,max-content)")
    end

    test "is the same in the header and in every row, so the columns line up" do
      for state <- [table_state(), three_buttons(table_state())] do
        html = render_table(state)

        assert header_tracks(html, state) == row_tracks(html)
      end
    end

    test "is never narrower than 120px, the room the header needs" do
      state = table_state()

      [publish | _] = state.static.row_actions
      state = %{state | static: %{state.static | row_actions: [publish], row_actions_layout: nil}}

      assert String.ends_with?(
               header_tracks(render_table(state), state),
               " minmax(120px,max-content)"
             )
    end

    test "is absent when no row action is visible" do
      state = table_state()

      state = %{
        state
        | static: %{
            state.static
            | row_actions: [],
              row_action_dropdowns: [],
              row_actions_layout: nil
          }
      }

      html = render_table(state)

      refute header_tracks(html, state) =~ "max-content"
      refute html =~ ~s(<div class="text-right px-[16px])
    end
  end

  describe "Shared.max_row_action_controls/2" do
    test "counts every action a row may draw" do
      actions = [action(:view), action(:edit), action(:delete, type: :destroy)]

      assert Shared.max_row_action_controls(static_with(actions), state_with()) == 3
    end

    test "counts an action whose visibility is decided per record" do
      actions = [action(:view), action(:publish, visible: fn _record, _state -> false end)]

      assert Shared.max_row_action_controls(static_with(actions), state_with()) == 2
    end

    test "leaves out an accordion, a hidden action and one for the other archive view" do
      actions = [
        action(:view),
        action(:expand, type: :accordion),
        action(:never, visible: false),
        action(:edit, visible: :active),
        action(:restore, type: :unarchive, visible: :archived)
      ]

      assert Shared.max_row_action_controls(static_with(actions), state_with()) == 2

      assert Shared.max_row_action_controls(
               static_with(actions),
               state_with(archive_status: :archived)
             ) == 2
    end

    test "leaves out a restricted action for a user who is not a master" do
      actions = [action(:view), action(:delete, restricted: true)]

      assert Shared.max_row_action_controls(static_with(actions), state_with()) == 2

      assert Shared.max_row_action_controls(static_with(actions), state_with(master_user?: false)) ==
               1
    end

    test "under a layout, counts the inline actions and one trigger per dropdown with an item" do
      actions = [action(:view), action(:edit), action(:archive)]

      dropdowns = [
        %{name: :more, items: [action(:duplicate), %{type: :separator}]},
        %{name: :danger, items: [action(:wipe, restricted: true)]}
      ]

      layout = %{inline: [:view, :edit], dropdown: [:more, :danger]}
      static = static_with(actions, dropdowns: dropdowns, layout: layout)

      assert Shared.max_row_action_controls(static, state_with()) == 4
      assert Shared.max_row_action_controls(static, state_with(master_user?: false)) == 3
    end
  end

  describe "the table's frame" do
    test "no longer hides its horizontal scrollbar" do
      class = render_table(table_state()) |> frame_class()

      refute class =~ "[scrollbar-width:none]"
      refute class =~ "-webkit-scrollbar]:hidden"
    end

    test "draws a thin scrollbar in the admin palette" do
      class = render_table(table_state()) |> frame_class()

      assert class =~ "overflow-x-auto"
      assert class =~ "[scrollbar-width:thin]"
      assert class =~ "[scrollbar-color:#d5d3cb_transparent]"
      assert class =~ "-webkit-scrollbar-thumb]:bg-[#d5d3cb]"
    end

    test "still lays rows out as cards, unscrolled, on a narrow screen" do
      class = render_table(table_state()) |> frame_class()

      assert class =~ "max-[980px]:overflow-visible!"
      assert class =~ "max-[980px]:border-0!"
    end
  end

  describe "a row action button" do
    test "dims and stops taking clicks while its click is pending" do
      html = render_table(three_buttons(table_state()))

      buttons = Regex.scan(~r/<button[^>]*class="grid size-\[30px\][^"]*"[^>]*>/, html)

      assert length(buttons) == 3

      for [button] <- buttons do
        assert button =~ "phx-click-loading:opacity-70"
        assert button =~ "phx-click-loading:pointer-events-none"
      end
    end
  end
end
