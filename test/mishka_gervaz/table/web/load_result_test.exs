defmodule MishkaGervaz.Table.Web.LoadResultTest do
  @moduledoc """
  What a load leaves in the table's state. Its rows reach the page through the stream only:
  `records_result` keeps the page the load read and whether that page was empty, and none of its
  rows, so the rows of a table left open are not held in the LiveView's memory. The `:no_results`
  notice is drawn from that emptiness, and a failed load still marks the result failed.
  """
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Web.{DataLoader, Renderer, State}
  alias MishkaGervaz.Table.Web.DataLoader.PaginationHandler
  alias MishkaGervaz.Test.DataLoader.BasicResource
  alias MishkaGervaz.Test.Resources.ChromeTable

  @master %{id: "master-1", site_id: nil, role: :admin}

  setup do
    on_exit(fn -> MishkaGervaz.Test.Ets.stop(BasicResource) end)
  end

  defp socket(state) do
    %Phoenix.LiveView.Socket{
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
    |> Phoenix.Component.assign(:table_state, state)
    |> Phoenix.Component.assign(:id, state.static.id)
    |> Phoenix.Component.assign(:skip_next_url_sync?, true)
    |> Phoenix.LiveView.stream(state.static.stream_name, [])
  end

  defp load(resource, page) do
    state =
      "table"
      |> State.init(resource, @master)
      |> State.update(loading: :loading, loading_type: :reset)

    result =
      PaginationHandler.Default.load_page(
        state,
        DataLoader.read_query(state),
        page,
        :master_read,
        nil
      )

    DataLoader.handle_async(:load_data, {:ok, result}, socket(state))
  end

  defp streamed_ids(socket) do
    state = socket.assigns.table_state

    for {_dom_id, _at, row, _limit, _update_only} <-
          socket.assigns.streams[state.static.stream_name].inserts,
        do: row.id
  end

  defp holds?(term, ids) when is_map(term),
    do: Map.get(term, :id) in ids or holds?(Map.values(term), ids)

  defp holds?(term, ids) when is_list(term), do: Enum.any?(term, &holds?(&1, ids))
  defp holds?(term, ids) when is_tuple(term), do: holds?(Tuple.to_list(term), ids)
  defp holds?(_term, _ids), do: false

  defp render_with_result(records_result) do
    state =
      "chrome"
      |> State.init(ChromeTable, @master)
      |> State.update(
        loading: :loaded,
        has_initial_data?: true,
        total_count: 0,
        records_result: records_result
      )

    render_component(&Renderer.render/1, %{
      table_state: state,
      streams: %{state.static.stream_name => []},
      myself: nil,
      __changed__: %{}
    })
  end

  test "a load's rows go to the stream, and the state holds none of them" do
    rows = Enum.map(1..7, &Ash.create!(BasicResource, %{name: "Item #{&1}"}))

    socket = load(BasicResource, 2)
    state = socket.assigns.table_state
    ids = Enum.map(rows, & &1.id)

    assert length(streamed_ids(socket)) == 2
    assert Enum.all?(streamed_ids(socket), &(&1 in ids))
    refute holds?(Map.from_struct(%{state | static: nil}), ids)
    assert state.records_result.ok?
    assert state.records_result.result == %{page: 2, empty?: false}
  end

  test "an empty page is marked empty" do
    socket = load(BasicResource, 1)

    assert socket.assigns.table_state.records_result.result == %{page: 1, empty?: true}
  end

  test "the :no_results notice is drawn after an empty load, and not after one with rows" do
    empty = Phoenix.LiveView.AsyncResult.ok(%{page: 1, empty?: true})
    full = Phoenix.LiveView.AsyncResult.ok(%{page: 1, empty?: false})

    assert render_with_result(empty) =~ "No records match your filters"
    refute render_with_result(full) =~ "No records match your filters"
  end

  test "a failed load marks the result failed and keeps no rows" do
    state = "table" |> State.init(BasicResource, @master) |> State.update(loading: :loading)
    socket = DataLoader.handle_async(:load_data, {:exit, :refused}, socket(state))

    assert socket.assigns.table_state.records_result.failed
    assert socket.assigns.table_state.loading == :error
  end
end
