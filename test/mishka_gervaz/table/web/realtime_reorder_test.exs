defmodule MishkaGervaz.Table.Web.RealtimeReorderTest do
  @moduledoc """
  `MishkaGervaz.Table.Web.Live.reorder/2`: rows whose sort field changed are drawn again in the
  table's order, which a realtime update, leaving a row where it stands, does not do.

  The table reads as many rows as it shows again from its first page, in its order, one more for
  each moved row, and draws them afresh in that order: a row moved in from a later page stands in
  its place, a row shown that now stands just past them stays below them, rows moved past them are
  not drawn, and a row shown further on leaves. A row handed in as a realtime notification in the
  same burst counts as shown. The footer's `shown_ids` follows what is drawn, and a burst is read
  once.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.{DataLoader, Live, State}
  alias MishkaGervaz.Test.DataLoader.BasicResource
  alias MishkaGervaz.Test.Queries

  setup do
    on_exit(fn -> MishkaGervaz.Test.Ets.stop(BasicResource) end)
    rows = Enum.map(1..7, &Ash.create!(BasicResource, %{name: "Item #{&1}"}))
    %{rows: rows}
  end

  defp master_user, do: %{id: "master-1", site_id: nil, role: :admin}

  # The first page of five read, by name: what Load more would read next starts at the sixth row.
  defp shown(rows, extra \\ []) do
    "table"
    |> State.init(BasicResource, master_user())
    |> State.update(
      loading: :loaded,
      total_count: length(rows),
      sort_fields: [name: :asc],
      next_offset: 5,
      shown_ids: MapSet.new(Enum.take(rows, 5) ++ extra, & &1.id)
    )
  end

  # Every row read, by name: the table shows the whole list, as a short list of files is.
  defp all_shown(rows),
    do: rows |> shown(Enum.drop(rows, 5)) |> State.update(next_offset: length(rows))

  defp created(record) do
    %Ash.Notifier.Notification{
      resource: BasicResource,
      action: Ash.Resource.Info.action(BasicResource, :create),
      data: record
    }
  end

  defp notify(socket, notification) do
    {:ok, socket} = Live.update(%{pubsub_notification: notification}, socket)
    socket
  end

  defp socket(state) do
    %Phoenix.LiveView.Socket{
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
    |> Phoenix.Component.assign(:table_state, state)
    |> Phoenix.Component.assign(:id, state.static.id)
    |> Phoenix.LiveView.stream(state.static.stream_name, [])
  end

  defp connected(socket), do: %{socket | transport_pid: self()}

  defp reorder(socket, moved) do
    {:ok, socket} = Live.update(%{id: socket.assigns.id, reorder: List.wrap(moved)}, socket)
    socket
  end

  defp flush(socket) do
    {:ok, socket} = Live.update(%{id: socket.assigns.id, realtime_flush: true}, socket)
    socket
  end

  # Two rows trade names, as two files trade positions when one moves past the other.
  defp swap!(first, second) do
    {
      Ash.update!(first, %{name: second.name}),
      Ash.update!(second, %{name: first.name})
    }
  end

  # The socket after a render: LiveView sends the stream's inserts and forgets them.
  defp rendered(socket) do
    name = socket.assigns.table_state.static.stream_name
    streams = Map.update!(socket.assigns.streams, name, &Phoenix.LiveView.LiveStream.prune/1)
    %{socket | assigns: %{socket.assigns | streams: streams}}
  end

  defp stream(socket), do: socket.assigns.streams[socket.assigns.table_state.static.stream_name]

  defp drawn_names(socket),
    do:
      socket |> stream() |> Map.fetch!(:inserts) |> Enum.reverse() |> Enum.map(&elem(&1, 2).name)

  defp drawn_ids(socket),
    do: socket |> stream() |> Map.fetch!(:inserts) |> Enum.reverse() |> Enum.map(&elem(&1, 2).id)

  test "two rows inside the pages that swap are drawn again in the new order", %{rows: rows} do
    [first, second | _rest] = rows
    {first, second} = swap!(first, second)

    socket = rows |> shown() |> socket() |> reorder([first, second])

    assert stream(socket).reset?
    assert drawn_ids(socket) == [second.id, first.id | rows |> Enum.slice(2, 3) |> ids()]
    assert drawn_names(socket) == Enum.map(1..5, &"Item #{&1}")
    assert socket.assigns.table_state.shown_ids == MapSet.new(drawn_ids(socket))
  end

  test "a row from the next page comes into its place and the row moved out stays below",
       %{rows: rows} do
    fifth = Enum.at(rows, 4)
    sixth = Enum.at(rows, 5)
    {fifth, sixth} = swap!(fifth, sixth)

    socket = rows |> shown() |> socket() |> reorder([fifth, sixth])

    assert drawn_ids(socket) == ids(Enum.take(rows, 4)) ++ [sixth.id, fifth.id]
    assert MapSet.size(socket.assigns.table_state.shown_ids) == 6
    assert socket.assigns.table_state.next_offset == 5
  end

  test "the two rows of a swap heard one at a time end in the same rows", %{rows: rows} do
    fifth = Enum.at(rows, 4)
    sixth = Enum.at(rows, 5)
    {fifth, sixth} = swap!(fifth, sixth)

    socket = rows |> shown() |> socket() |> reorder(sixth)

    assert drawn_ids(socket) == ids(Enum.take(rows, 4)) ++ [sixth.id, fifth.id]

    socket = socket |> rendered() |> reorder(fifth)

    assert drawn_ids(socket) == ids(Enum.take(rows, 4)) ++ [sixth.id, fifth.id]
    assert MapSet.size(socket.assigns.table_state.shown_ids) == 6
  end

  test "rows that swap past the rows shown are not drawn", %{rows: rows} do
    swap!(Enum.at(rows, 5), Enum.at(rows, 6))
    moved = rows |> Enum.slice(5, 2) |> Enum.map(&Ash.get!(BasicResource, &1.id))

    socket = rows |> shown() |> socket() |> reorder(moved)

    assert drawn_ids(socket) == ids(Enum.take(rows, 5))
    assert MapSet.size(socket.assigns.table_state.shown_ids) == 5
  end

  test "a row shown further on, as one that arrived at the top, leaves", %{rows: rows} do
    arrived = 8..9 |> Enum.map(&Ash.create!(BasicResource, %{name: "Item #{&1}"})) |> List.last()
    [first, second | _rest] = rows
    {first, second} = swap!(first, second)

    socket = rows |> shown([arrived]) |> socket() |> reorder([first, second])

    assert drawn_ids(socket) == [second.id, first.id | rows |> Enum.slice(2, 4) |> ids()]
    refute MapSet.member?(socket.assigns.table_state.shown_ids, arrived.id)
  end

  test "a row that arrived where the order puts it stays", %{rows: rows} do
    [first, second | _rest] = rows
    arrived = Ash.create!(BasicResource, %{name: "Item 0"})
    {first, second} = swap!(first, second)

    socket = rows |> shown([arrived]) |> socket() |> reorder([first, second])

    assert drawn_ids(socket) == [
             arrived.id,
             second.id,
             first.id | rows |> Enum.slice(2, 3) |> ids()
           ]
  end

  test "a row handed in and asked for in order in one burst is drawn in its place at the end",
       %{rows: rows} do
    socket = rows |> all_shown() |> socket() |> connected()
    arrived = Ash.create!(BasicResource, %{name: "Item 8"})

    socket = socket |> notify(created(arrived)) |> reorder(arrived)

    assert stream(socket).inserts == []
    assert_received {:phoenix, :send_update, {{Live, "table"}, %{realtime_flush: true}}}
    refute_received {:phoenix, :send_update, _second_flush}

    {socket, on_flush} = Queries.count(fn -> flush(socket) end)

    assert drawn_ids(socket) == ids(rows) ++ [arrived.id]
    assert MapSet.member?(socket.assigns.table_state.shown_ids, arrived.id)
    assert on_flush == 1
  end

  test "a row handed in whose place is past a later page's rows waits for Load more",
       %{rows: rows} do
    arrived = Ash.create!(BasicResource, %{name: "Item 8"})

    socket = rows |> shown() |> socket() |> connected() |> notify(created(arrived))
    socket = socket |> reorder(arrived) |> flush()

    assert drawn_ids(socket) == ids(Enum.take(rows, 5))
    refute MapSet.member?(socket.assigns.table_state.shown_ids, arrived.id)
  end

  test "a burst on a connected socket waits and is read once", %{rows: rows} do
    [first, second | _rest] = rows
    {first, second} = swap!(first, second)

    {socket, while_waiting} =
      Queries.count(fn ->
        rows |> shown() |> socket() |> connected() |> reorder(first) |> reorder(second)
      end)

    assert while_waiting == 0
    assert stream(socket).inserts == []
    assert_received {:phoenix, :send_update, {{Live, "table"}, %{realtime_flush: true}}}
    refute_received {:phoenix, :send_update, _second_flush}

    {socket, on_flush} = Queries.count(fn -> flush(socket) end)

    assert on_flush == 1
    assert Enum.take(drawn_ids(socket), 2) == [second.id, first.id]
  end

  test "while the table loads its rows afresh, reads nothing", %{rows: rows} do
    state = rows |> shown() |> State.update(loading: :loading, loading_type: :reset)

    {socket, queries} = Queries.count(fn -> state |> socket() |> reorder(hd(rows)) end)

    assert queries == 0
    refute stream(socket).reset?
  end

  test "rows_in_window/2 reads as many rows as are shown and the ones after them, in order",
       %{rows: rows} do
    assert {:ok, covered, next} = DataLoader.rows_in_window(shown(rows), 2)
    assert ids(covered) == ids(Enum.take(rows, 5))
    assert ids(next) == ids(Enum.slice(rows, 5, 2))
  end

  defp ids(rows), do: Enum.map(rows, & &1.id)
end
