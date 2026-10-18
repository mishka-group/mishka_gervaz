defmodule MishkaGervaz.Test.Web.LoadGate do
  @moduledoc """
  A `MishkaGervaz.Table.Web.DataLoader.PaginationHandler` whose loads wait while the gate is closed.

  Start it with `start_supervised!(LoadGate)`; it starts open. After `close/0` every load that
  reaches `load_page/5` waits, until `open/0` lets the waiting ones and every later one through.
  With no gate running, loads go straight through.

      LoadGate.close()
      # the reader picks a filter: its load waits here
      LoadGate.open()
      render_async(view)
  """

  use GenServer
  use MishkaGervaz.Table.Web.DataLoader.PaginationHandler

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_opts), do: GenServer.start_link(__MODULE__, :open, name: __MODULE__)

  @doc "Holds every load that starts from now on."
  @spec close() :: :ok
  def close, do: GenServer.call(__MODULE__, :close)

  @doc "Lets the held loads and every later one through."
  @spec open() :: :ok
  def open, do: GenServer.call(__MODULE__, :open)

  def load_page(state, query, page, action, tenant) do
    pass()
    super(state, query, page, action, tenant)
  end

  defp pass do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      gate -> GenServer.call(gate, :pass, :infinity)
    end
  end

  @impl GenServer
  def init(position), do: {:ok, {position, []}}

  @impl GenServer
  def handle_call(:pass, _from, {:open, _held} = gate), do: {:reply, :ok, gate}
  def handle_call(:pass, from, {:closed, held}), do: {:noreply, {:closed, [from | held]}}
  def handle_call(:close, _from, {_position, held}), do: {:reply, :ok, {:closed, held}}

  def handle_call(:open, _from, {_position, held}) do
    Enum.each(held, &GenServer.reply(&1, :ok))
    {:reply, :ok, {:open, []}}
  end
end
