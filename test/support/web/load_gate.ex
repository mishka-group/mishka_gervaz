defmodule MishkaGervaz.Test.Web.LoadGate do
  @moduledoc """
  A `MishkaGervaz.Table.Web.DataLoader.PaginationHandler` whose loads wait while the gate is closed,
  and fail while it is broken.

  Start it with `start_supervised!(LoadGate)`; it starts open. After `close/0` every load that
  reaches `load_page/5` waits, until `open/0` lets the waiting ones and every later one through.
  After `break/0` every load raises, as a read the database refuses does, until `open/0`. With no
  gate running, loads go straight through.

      LoadGate.close()
      # the reader picks a filter: its load waits here
      LoadGate.open()
      render_async(view)
  """

  use GenServer
  use MishkaGervaz.Table.Web.DataLoader.PaginationHandler

  @refused "the database refused the read"

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_opts), do: GenServer.start_link(__MODULE__, :open, name: __MODULE__)

  @doc "Holds every load that starts from now on."
  @spec close() :: :ok
  def close, do: GenServer.call(__MODULE__, :close)

  @doc "Lets the held loads and every later one through."
  @spec open() :: :ok
  def open, do: GenServer.call(__MODULE__, :open)

  @doc "Makes every load that starts from now on raise, until `open/0`."
  @spec break() :: :ok
  def break, do: GenServer.call(__MODULE__, :break)

  @doc """
  The processes of the loads the broken gate failed. Each logs its exception as it exits, so a test
  that waits for them to exit has the log.
  """
  @spec failed() :: [pid()]
  def failed, do: GenServer.call(__MODULE__, :failed)

  @doc "The message of the exception a load raises while the gate is broken."
  @spec refused() :: String.t()
  def refused, do: @refused

  def load_page(state, query, page, action, tenant) do
    pass()
    super(state, query, page, action, tenant)
  end

  defp pass do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      gate -> gate |> GenServer.call(:pass, :infinity) |> through()
    end
  end

  defp through(:ok), do: :ok
  defp through(:broken), do: raise(@refused)

  @impl GenServer
  def init(position), do: {:ok, {position, [], []}}

  @impl GenServer
  def handle_call(:pass, _from, {:open, _held, _failed} = gate), do: {:reply, :ok, gate}

  def handle_call(:pass, from, {:closed, held, failed}),
    do: {:noreply, {:closed, [from | held], failed}}

  def handle_call(:pass, {pid, _tag}, {:broken, held, failed}),
    do: {:reply, :broken, {:broken, held, [pid | failed]}}

  def handle_call(:close, _from, {_position, held, failed}),
    do: {:reply, :ok, {:closed, held, failed}}

  def handle_call(:break, _from, {_position, held, failed}),
    do: {:reply, :ok, {:broken, held, failed}}

  def handle_call(:failed, _from, {_position, _held, failed} = gate), do: {:reply, failed, gate}

  def handle_call(:open, _from, {_position, held, failed}) do
    Enum.each(held, &GenServer.reply(&1, :ok))
    {:reply, :ok, {:open, [], failed}}
  end
end
