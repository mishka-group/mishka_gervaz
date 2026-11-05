defmodule MishkaGervaz.Test.Queries do
  @moduledoc """
  Counts the queries Ash runs while a function runs: every read, a relationship load included,
  and every aggregate, such as `Ash.count/2` and `Ash.exists/2`, of the test resources' domains.

  Ash reports each through telemetry from the process that runs it, so the work of a task or a
  LiveView counts as well, as long as the function waits for it to end. Use it from a test module
  with `async: false`, so no other test's queries are counted.

      {socket, queries} = Queries.count(fn -> Live.update(assigns, socket) end)
      assert queries == 1
  """

  @events for kind <- [:read, :aggregate], do: [:ash, :domain, kind, :start]

  @doc "Runs `fun` and returns its result with the number of queries Ash ran meanwhile."
  @spec count((-> result)) :: {result, non_neg_integer()} when result: term()
  def count(fun) do
    counter = :counters.new(1, [])
    id = {__MODULE__, make_ref()}
    :ok = :telemetry.attach_many(id, @events, &__MODULE__.handle_event/4, counter)

    try do
      result = fun.()
      {result, :counters.get(counter, 1)}
    after
      :telemetry.detach(id)
    end
  end

  @doc false
  def handle_event(_event, _measurements, _metadata, counter), do: :counters.add(counter, 1, 1)
end
