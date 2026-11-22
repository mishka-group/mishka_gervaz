defmodule MishkaGervaz.Form.Web.LiveErrorsTest do
  @moduledoc """
  A field with `live_errors true` shows its own error as it is typed, before a new record's first
  save, once it holds a value; a field without it, and an empty one, wait for the save.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Web.{Events, Live}
  alias MishkaGervaz.Test.Resources.LiveCheckEntry

  @user %{id: "user-1", site_id: nil}

  defp mount do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        %{id: "live-check-entry", resource: LiveCheckEntry, current_user: @user},
        socket
      )

    socket
  end

  defp typed(socket, params) do
    {:noreply, socket} =
      Events.handle("validate", %{"form" => params, "_target" => ["form", "code"]}, socket)

    socket.assigns.form_state.errors
  end

  test "a live field's error is shown as it is typed, and the required title waits" do
    errors = typed(mount(), %{"title" => "", "code" => "abc"})

    assert [_message] = errors[:code]
    refute Map.has_key?(errors, :title)
  end

  test "an empty live field shows nothing, and a right value clears its error" do
    socket = mount()

    assert typed(socket, %{"title" => "", "code" => ""}) == %{}
    assert typed(socket, %{"title" => "", "code" => "ABC"}) == %{}
  end

  test "after a refused save every field shows its errors" do
    {:noreply, socket} =
      Events.handle("save", %{"form" => %{"title" => "", "code" => "ABC"}}, mount())

    assert Map.has_key?(socket.assigns.form_state.errors, :title)
  end
end
