defmodule MishkaGervaz.MessagesTest do
  @moduledoc """
  Work `MishkaGervaz.Messages` hands to another process runs in the Gettext locales of the process
  that handed it over.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Messages

  @backend MishkaGervaz.Test.Gettext

  defp socket do
    %Phoenix.LiveView.Socket{
      transport_pid: self(),
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  defp locales, do: {Gettext.get_locale(), Gettext.get_locale(@backend)}

  # The task sends its result to the socket's transport before it exits, so once it is down the
  # result is already in the mailbox.
  defp await_task(socket, key) do
    {_ref, pid, _kind} = socket.private.live_async[key]
    monitor = Process.monitor(pid)
    assert_receive {:DOWN, ^monitor, :process, ^pid, _reason}, 60_000
  end

  setup do
    Gettext.put_locale("de")
    Gettext.put_locale(@backend, "fa")
    :ok
  end

  test "a task runs in the caller's locales" do
    assert {"de", "fa"} == Task.async(Messages.in_caller_locale(&locales/0)) |> Task.await()

    assert [ok: {:x, {"de", "fa"}}] ==
             Task.async_stream([:x], Messages.in_caller_locale(&{&1, locales()}))
             |> Enum.to_list()
  end

  test "a task started with no locale set runs in the default one" do
    Process.delete(Gettext)
    Process.delete(@backend)

    assert {"en", "en"} == Task.async(Messages.in_caller_locale(&locales/0)) |> Task.await()
  end

  test "start_async runs its function in the caller's locales" do
    socket() |> Messages.start_async(:probe, &locales/0) |> await_task(:probe)

    assert_received {:phoenix, :async_result, {:start, {_ref, _cid, :probe, {:ok, {"de", "fa"}}}}}
  end

  test "assign_async runs its function in the caller's locales" do
    socket()
    |> Messages.assign_async(:probe, fn -> {:ok, %{probe: locales()}} end)
    |> await_task([:probe])

    assert_received {:phoenix, :async_result,
                     {:assign, {_ref, _cid, [:probe], {:ok, {:ok, %{probe: {"de", "fa"}}}}}}}
  end
end
