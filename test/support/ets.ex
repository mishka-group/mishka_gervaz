defmodule MishkaGervaz.Test.Ets do
  @moduledoc """
  Empties an ETS-backed test resource. Use it wherever a test clears a resource's rows.

  `stop/1` returns once the table's manager has exited, so a create that follows starts a fresh
  table. `Ash.DataLayer.Ets.stop/1` alone only signals the manager, and a create straight after it
  can land in the old table as it is deleted (`ETS.Set.get!/3 returned {:error, :table_not_found}`).
  """

  @spec stop(Ash.Resource.t()) :: :ok
  def stop(resource) do
    manager = manager(resource)
    ref = manager && Process.monitor(manager)

    Ash.DataLayer.Ets.stop(resource)

    if ref do
      receive do
        {:DOWN, ^ref, :process, ^manager, _reason} -> :ok
      after
        5_000 -> raise "the ETS table manager of #{inspect(resource)} did not exit"
      end
    end

    :ok
  end

  defp manager(resource) do
    case Ash.DataLayer.Ets.table_name(resource, nil, false) do
      {:ok, table} -> Process.whereis(Module.concat(table, Ash.DataLayer.Ets.TableManager))
      _no_table -> nil
    end
  end
end
