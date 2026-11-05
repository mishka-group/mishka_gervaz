defmodule MishkaGervaz.Table.Web.RowActionRulesTest do
  @moduledoc """
  The built-in rules of `hooks` (`redirect_on_empty`, `switch_to_active_on_empty_archive`,
  `switch_to_archive_on_empty_active`, `reset_page_on_empty_current_page`) after a row action.

  A delete, a destroy, a restore or a permanent destroy takes its row off the table's total, and
  the rules are answered from that total at once: no page of rows is read again to learn it. A rule
  that moves the table, such as switching to the active view, loads what it moves to.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.{Events, State}
  alias MishkaGervaz.Test.DataLoader.{ArchivableResource, BasicResource}
  alias MishkaGervaz.Test.Queries

  @master %{id: "master-1", site_id: nil, role: :admin}

  setup do
    on_exit(fn ->
      Enum.each([ArchivableResource, BasicResource], &MishkaGervaz.Test.Ets.stop/1)
    end)
  end

  defp loaded(resource, total, builtins, updates \\ []) do
    state =
      "table"
      |> State.init(resource, @master)
      |> State.update(
        Keyword.merge(
          [loading: :loaded, has_initial_data?: true, total_count: total, total_pages: 1],
          updates
        )
      )

    hooks = Map.put(state.static.hooks || %{}, :__builtins__, builtins)
    %{state | static: %{state.static | hooks: hooks}}
  end

  defp socket(state) do
    %Phoenix.LiveView.Socket{
      transport_pid: self(),
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
    |> Phoenix.Component.assign(:table_state, state)
    |> Phoenix.Component.assign(:id, state.static.id)
    |> Phoenix.LiveView.stream(state.static.stream_name, [])
  end

  defp run(socket, event, id) do
    Queries.count(fn ->
      {:noreply, socket} = Events.handle(event, %{"id" => to_string(id)}, socket)
      socket
    end)
  end

  defp loading?(socket), do: not is_nil(socket.private[:live_async][:load_data])

  test "deleting the last row redirects at once, and reads no page again" do
    [row] = Enum.map(1..1, &Ash.create!(BasicResource, %{name: "Item #{&1}"}))
    state = loaded(BasicResource, 1, %{redirect_on_empty: "/admin/done"})

    {socket, queries} = state |> socket() |> run("delete", row.id)

    assert socket.redirected == {:live, :redirect, %{kind: :push, to: "/admin/done"}}
    assert socket.assigns.table_state.total_count == 0
    refute loading?(socket)
    assert queries == 1, "the read of the row the delete acts on"
  end

  test "deleting a row that leaves others stays, and reads no page again" do
    [row | _rest] = Enum.map(1..3, &Ash.create!(BasicResource, %{name: "Item #{&1}"}))
    state = loaded(BasicResource, 3, %{redirect_on_empty: "/admin/done"})

    {socket, queries} = state |> socket() |> run("delete", row.id)

    assert socket.redirected == nil
    assert socket.assigns.table_state.total_count == 2
    refute loading?(socket)
    assert queries == 1
  end

  test "restoring the last archived row switches to the active view, which it loads" do
    [row] = Enum.map(1..1, &Ash.create!(ArchivableResource, %{name: "Item #{&1}"}))
    Ash.destroy!(row)

    state =
      loaded(ArchivableResource, 1, %{switch_to_active_on_empty_archive: true},
        archive_status: :archived
      )

    {socket, _queries} = state |> socket() |> run("unarchive", row.id)

    assert socket.assigns.table_state.archive_status == :active
    assert loading?(socket)
  end

  test "restoring an archived row that leaves others takes it off the archived total" do
    rows = Enum.map(1..2, &Ash.create!(ArchivableResource, %{name: "Item #{&1}"}))
    Enum.each(rows, &Ash.destroy!/1)

    state =
      loaded(ArchivableResource, 2, %{switch_to_active_on_empty_archive: true},
        archive_status: :archived
      )

    {socket, _queries} = state |> socket() |> run("unarchive", hd(rows).id)

    assert socket.assigns.table_state.archive_status == :archived
    assert socket.assigns.table_state.total_count == 1
    refute loading?(socket)
  end

  test "destroying an archived row for good takes it off the archived total" do
    rows = Enum.map(1..2, &Ash.create!(ArchivableResource, %{name: "Item #{&1}"}))
    Enum.each(rows, &Ash.destroy!/1)

    state =
      loaded(ArchivableResource, 2, %{redirect_on_empty: "/admin/done"},
        archive_status: :archived
      )

    {socket, _queries} = state |> socket() |> run("permanent_destroy", hd(rows).id)

    assert socket.assigns.table_state.total_count == 1
    assert socket.redirected == nil
    refute loading?(socket)
  end
end
