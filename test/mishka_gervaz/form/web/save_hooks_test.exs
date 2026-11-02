defmodule MishkaGervaz.Form.Web.SaveHooksTest do
  @moduledoc """
  The server hooks a save runs.

  `before_save` may return the params to save, as a bare map or as `{:cont, params}`, or
  `{:halt, reason}` to refuse the save. `after_save` runs with the saved record, and `on_error` with
  the form a failed save left, and the state it returns is the one the form shows.
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

  describe "after_save" do
    test "runs with the saved record" do
      mount() |> save(%{"title" => "hello"})

      assert_received {:after_save_hook, "HELLO"}
    end

    test "does not run when the save fails" do
      mount() |> save(%{"title" => ""})

      refute_received {:after_save_hook, _title}
    end
  end

  describe "on_error" do
    test "runs with the form a failed save left, and the form shows the state it returns" do
      socket = mount() |> save(%{"title" => ""})

      assert_received {:on_error_hook, :create}
      assert "Checked by the hook." in socket.assigns.form_state.form_errors
      assert socket.assigns.form_state.errors != %{}
    end

    test "does not run when the save succeeds" do
      mount() |> save(%{"title" => "hello"})

      refute_received {:on_error_hook, _type}
    end
  end
end
