defmodule MishkaGervaz.Table.Templates.ActionsTrackTest do
  @moduledoc """
  The Actions column is as wide as the most controls a row on the page draws, the header and every
  row read that one track from the rows' container, and a table wider than its frame shows a
  scrollbar to reach the rest.

  Each control is a 30px square, 4px from the next, inside 16px of padding on either side: three
  of them need 130px, two 96px. An action whose `visible` rule leaves it out of every row on the
  page, such as an archived-only Restore in the active view, takes no room. The column is never
  narrower than the 80px the header's "Actions" needs. Each control dims while its click is
  pending.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.{DataLoader, State}
  alias MishkaGervaz.Test.Resources.TranslatedDsl

  @admin %{id: "user-1", role: :admin}
  @record %{id: "row-1", title: "Cat", slug: "cat", status: :published, featured: true}
  @main %{
    id: "main",
    title: "Main",
    slug: "main",
    status: :published,
    featured: false,
    main: true
  }
  @other %{id: "other", title: "B", slug: "b", status: :published, featured: false, main: false}

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

  # Row actions shaped like a site's: View and Edit in the active view, Delete in the active view
  # for every row but the main one, Restore and Delete permanently in the archived view.
  defp site_actions(state) do
    actions = [
      action(:view, visible: :active),
      action(:edit, visible: :active),
      action(:expand, type: :accordion),
      action(:delete,
        type: :destroy,
        visible: fn record, state -> state.archive_status == :active and not record.main end
      ),
      action(:restore, type: :unarchive, visible: :archived),
      action(:purge, type: :permanent_destroy, visible: :archived)
    ]

    static = %{
      state.static
      | row_actions: actions,
        row_actions_layout: nil,
        row_action_dropdowns: []
    }

    %{state | static: static}
  end

  defp counted(state, records),
    do: state |> State.update(row_action_controls: 0) |> State.fit_row_actions(records)

  defp render_table(state, records \\ [@record]) do
    stream_name = state.static.stream_name

    render_component(&TableTemplate.render/1, %{
      static: state.static,
      state: state,
      stream: Enum.map(records, &{"#{stream_name}-#{&1.id}", &1}),
      streams: %{stream_name => []},
      empty?: false,
      myself: nil,
      __changed__: %{}
    })
  end

  defp actions_track(html) do
    case Regex.run(~r/style="--gervaz-actions-track: ([^"]*)"/, html) do
      [_, track] -> track
      nil -> nil
    end
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
    ~r/class="gervaz-row grid[^"]*"\s+style="grid-template-columns: ([^"]*);"/
    |> Regex.scan(html)
    |> Enum.map(fn [_, tracks] -> tracks end)
  end

  defp frame_class(html) do
    [_, class] = Regex.run(~r/data-role="gervaz-table-frame"[^>]*?\sclass="([^"]*)"/, html)
    class
  end

  # The buttons in the Actions cell of the record's row.
  defp drawn_buttons(html, record_id) do
    [_, group] = String.split(html, ~s(-#{record_id}" class="gervaz-row-group), parts: 2)
    [group | _] = String.split(group, ~s(class="gervaz-row-group), parts: 2)
    [_, cell] = String.split(group, ~s(data-role="gervaz-row-actions"), parts: 2)

    length(Regex.scan(~r/<button/, cell))
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
    test "fits three buttons with their padding" do
      state = table_state() |> three_buttons() |> counted([@record])

      assert actions_track(render_table(state)) == "minmax(130px,max-content)"
    end

    test "grows with each control a row draws, a dropdown's trigger included" do
      state = table_state() |> counted([@record])

      assert actions_track(render_table(state)) == "minmax(164px,max-content)"
    end

    test "is read by the header and by every row from the rows' container" do
      for state <- [table_state(), three_buttons(table_state())] do
        html = render_table(state, [@record, %{@record | id: "row-2"}])

        assert String.ends_with?(header_tracks(html, state), " var(--gervaz-actions-track)")
        assert row_tracks(html) == [header_tracks(html, state), header_tracks(html, state)]
        assert html =~ ~s(class="min-[980px]:min-w-min" style="--gervaz-actions-track: )
      end
    end

    test "is never narrower than the 80px the header's label needs" do
      state = table_state()

      [publish | _] = state.static.row_actions
      state = %{state | static: %{state.static | row_actions: [publish], row_actions_layout: nil}}

      assert actions_track(render_table(counted(state, [@record]))) ==
               "minmax(80px,max-content)"
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

      assert actions_track(html) == nil
      refute header_tracks(html, state) =~ "--gervaz-actions-track"
      refute html =~ ~s(data-role="gervaz-actions-header")
      refute html =~ ~s(data-role="gervaz-row-actions")
    end
  end

  describe "the Actions track in the active and the archived view" do
    test "in the active view, fits View, Edit and Delete, not Restore or Delete permanently" do
      state = table_state() |> site_actions()
      state = counted(state, [@main, @other])
      html = render_table(state, [@main, @other])

      assert drawn_buttons(html, "other") == 3
      assert drawn_buttons(html, "main") == 2
      assert state.row_action_controls == 3
      assert actions_track(html) == "minmax(130px,max-content)"
    end

    test "in the active view, fits two buttons when no row on the page draws Delete" do
      state = table_state() |> site_actions() |> counted([@main])
      html = render_table(state, [@main])

      assert drawn_buttons(html, "main") == 2
      assert actions_track(html) == "minmax(96px,max-content)"
    end

    test "in the archived view, fits Restore and Delete permanently only" do
      state =
        table_state(archive_status: :archived)
        |> site_actions()
        |> counted([@main, @other])

      html = render_table(state, [@main, @other])

      assert drawn_buttons(html, "other") == 2
      assert drawn_buttons(html, "main") == 2
      assert actions_track(html) == "minmax(96px,max-content)"
    end

    test "before the rows are counted, fits the most controls any row could draw" do
      state = table_state() |> site_actions()

      assert state.row_action_controls == nil
      assert actions_track(render_table(state, [@main])) == "minmax(130px,max-content)"
    end
  end

  describe "the rows the Actions track is counted from" do
    defp socket(state) do
      %Phoenix.LiveView.Socket{
        private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
      }
      |> Phoenix.Component.assign(:table_state, state)
      |> Phoenix.Component.assign(:id, state.static.id)
      |> Phoenix.Component.assign(:skip_next_url_sync?, true)
      |> Phoenix.LiveView.stream(state.static.stream_name, [])
    end

    defp load(socket, records, reset) do
      page = {1, %{results: records, more?: false}, reset, %{total_count: length(records)}}

      socket
      |> Phoenix.Component.assign(:skip_next_url_sync?, true)
      |> then(&DataLoader.handle_async(:load_data, {:ok, page}, &1))
    end

    defp controls(socket), do: socket.assigns.table_state.row_action_controls

    test "a load counts the rows it brings" do
      socket = table_state() |> site_actions() |> socket()

      assert socket |> load([@main], true) |> controls() == 2
      assert socket |> load([@main, @other], true) |> controls() == 3
    end

    test "a load that replaces the rows counts again from nothing" do
      socket = table_state() |> site_actions() |> socket()

      assert socket |> load([@other], true) |> load([@main], true) |> controls() == 2
    end

    test "a load that adds rows keeps the rows already drawn in the count" do
      socket = table_state() |> site_actions() |> socket()

      assert socket |> load([@other], true) |> load([@main], false) |> controls() == 3
      assert socket |> load([@main], true) |> load([@other], false) |> controls() == 3
    end

    test "a row inserted on its own widens the track when it draws more" do
      state = table_state() |> site_actions()
      socket = state |> socket() |> load([@main], true)

      socket = DataLoader.insert_row(socket, state, @other, at: 0)

      assert controls(socket) == 3

      [{_dom_id, 0, record, _limit, _update_only}] =
        socket.assigns.streams[state.static.stream_name].inserts
        |> Enum.filter(fn {_dom_id, _at, record, _limit, _update_only} ->
          record.id == "other"
        end)

      assert record == @other
    end

    test "a row inserted on its own never narrows the track" do
      state = table_state() |> site_actions()
      socket = state |> socket() |> load([@other], true)

      assert socket |> DataLoader.insert_row(state, @main) |> controls() == 3
    end
  end

  describe "Shared.row_action_controls/3" do
    test "counts each action its row shows, deciding a per-record rule for the record" do
      actions = [
        action(:view),
        action(:publish, visible: fn record, _state -> record.draft end)
      ]

      assert Shared.row_action_controls(static_with(actions), %{draft: true}, state_with()) == 2
      assert Shared.row_action_controls(static_with(actions), %{draft: false}, state_with()) == 1
    end

    test "leaves out an accordion, a hidden action and one for the other archive view" do
      actions = [
        action(:view),
        action(:expand, type: :accordion),
        action(:never, visible: false),
        action(:edit, visible: :active),
        action(:restore, type: :unarchive, visible: :archived)
      ]

      assert Shared.row_action_controls(static_with(actions), @record, state_with()) == 2

      assert Shared.row_action_controls(
               static_with(actions),
               @record,
               state_with(archive_status: :archived)
             ) == 2
    end

    test "leaves out a restricted action for a user who is not a master" do
      actions = [action(:view), action(:delete, restricted: true)]

      assert Shared.row_action_controls(static_with(actions), @record, state_with()) == 2

      assert Shared.row_action_controls(
               static_with(actions),
               @record,
               state_with(master_user?: false)
             ) == 1
    end

    test "under a layout, counts the inline actions and one trigger per dropdown its row shows" do
      actions = [
        action(:view),
        action(:edit, visible: fn record, _state -> record.draft end),
        action(:archive)
      ]

      dropdowns = [
        %{name: :more, items: [action(:duplicate), %{type: :separator}]},
        %{name: :danger, items: [action(:wipe, visible: fn record, _state -> record.draft end)]}
      ]

      layout = %{inline: [:view, :edit], dropdown: [:more, :danger]}
      static = static_with(actions, dropdowns: dropdowns, layout: layout)

      assert Shared.row_action_controls(static, %{draft: true}, state_with()) == 4
      assert Shared.row_action_controls(static, %{draft: false}, state_with()) == 2
    end

    test "matches the buttons the row draws" do
      state = table_state() |> site_actions()
      html = render_table(state, [@main, @other])

      for record <- [@main, @other] do
        assert Shared.row_action_controls(state.static, record, state) ==
                 drawn_buttons(html, record.id)
      end
    end
  end

  describe "State.fit_row_actions/2" do
    test "raises the count to the most controls any of the rows draws" do
      state = table_state() |> site_actions() |> State.update(row_action_controls: 0)

      assert State.fit_row_actions(state, [@main]).row_action_controls == 2
      assert State.fit_row_actions(state, [@main, @other]).row_action_controls == 3
    end

    test "never lowers the count" do
      state = table_state() |> site_actions() |> State.update(row_action_controls: 3)

      assert State.fit_row_actions(state, [@main]).row_action_controls == 3
    end

    test "leaves a count the table never made" do
      state = table_state() |> site_actions()

      assert State.fit_row_actions(state, [@other]).row_action_controls == nil
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
