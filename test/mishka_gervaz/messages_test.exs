defmodule MishkaGervaz.MessagesTest do
  @moduledoc """
  Work `MishkaGervaz.Messages` hands to another process runs in the Gettext locales of the process
  that handed it over.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Messages

  @backend MishkaGervaz.Test.Gettext
  @tenant {__MODULE__, :tenant}
  @unregistered {__MODULE__, :unregistered}

  defp socket do
    %Phoenix.LiveView.Socket{
      transport_pid: self(),
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  defp locales, do: {Gettext.get_locale(), Gettext.get_locale(@backend)}

  defp held, do: {Process.get(@tenant, :unset), Process.get(@unregistered, :unset)}

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

  describe "a registered process dictionary key" do
    setup do
      :ok = Messages.carry_process_keys([@tenant])
      Process.put(@tenant, "acme")
      Process.put(@unregistered, "kept here")
      :ok
    end

    test "is carried into a task with its caller's value, and an unregistered one is not" do
      assert {"acme", :unset} == Task.async(Messages.in_caller_locale(&held/0)) |> Task.await()

      assert [ok: {:x, {"acme", :unset}}] ==
               Task.async_stream([:x], Messages.in_caller_locale(&{&1, held()}))
               |> Enum.to_list()
    end

    test "is carried by start_async, beside the locales" do
      socket()
      |> Messages.start_async(:probe, fn -> {held(), locales()} end)
      |> await_task(:probe)

      assert_received {:phoenix, :async_result,
                       {:start, {_ref, _cid, :probe, {:ok, {{"acme", :unset}, {"de", "fa"}}}}}}
    end

    test "is carried by assign_async" do
      socket()
      |> Messages.assign_async(:probe, fn -> {:ok, %{probe: held()}} end)
      |> await_task([:probe])

      assert_received {:phoenix, :async_result,
                       {:assign, {_ref, _cid, [:probe], {:ok, {:ok, %{probe: {"acme", :unset}}}}}}}
    end

    test "is read when the function is wrapped" do
      wrapped = Messages.in_caller_locale(&held/0)
      Process.put(@tenant, "changed after")

      assert {"acme", :unset} == Task.async(wrapped) |> Task.await()
    end

    test "is not carried while the caller holds no value for it" do
      Process.delete(@tenant)

      assert {:unset, :unset} == Task.async(Messages.in_caller_locale(&held/0)) |> Task.await()
    end

    test "is listed once however often it is registered" do
      :ok = Messages.carry_process_keys([@tenant, @tenant])

      assert Enum.count(Messages.carried_process_keys(), &(&1 == @tenant)) == 1
    end
  end
end
