defmodule MishkaGervaz.Form.Web.SaveHooksTest do
  @moduledoc """
  The server hooks a save runs.

  `before_save` may return the params to save, as a bare map or as `{:cont, params}`, or
  `{:halt, reason}` to refuse the save.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Web.{Events, Live}
  alias MishkaGervaz.Test.Resources.HookedEntry

  @user %{id: "user-1", site_id: nil}

  setup do
    HookedEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp mount do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(%{id: "hooked-entry", resource: HookedEntry, current_user: @user}, socket)

    socket
  end

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  describe "before_save" do
    test "saves the params it returns as a bare map" do
      mount() |> save(%{"title" => "hello"})

      assert [%{title: "HELLO"}] = Ash.read!(HookedEntry)
    end
  end
end
