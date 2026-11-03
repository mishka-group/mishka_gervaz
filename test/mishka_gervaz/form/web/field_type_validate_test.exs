defmodule MishkaGervaz.Form.Web.FieldTypeValidateTest do
  @moduledoc """
  A field type's `validate/2` refuses a save as it refuses a value while typing: the record is not
  written and the field shows the type's message.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Web.{Events, Live}
  alias MishkaGervaz.Test.Resources.ColoredEntry

  @user %{id: "user-1", site_id: nil}

  setup do
    ColoredEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp mount do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(%{id: "colored-entry", resource: ColoredEntry, current_user: @user}, socket)

    socket
  end

  defp event(socket, "validate", params) do
    {:noreply, socket} =
      Events.handle("validate", %{"form" => params, "_target" => ["form", "color"]}, socket)

    socket
  end

  defp event(socket, name, params) do
    {:noreply, socket} = Events.handle(name, %{"form" => params}, socket)
    socket
  end

  test "a value the type refuses is shown while typing" do
    socket = event(mount(), "validate", %{"color" => "red"})

    assert ["must be a hex colour"] =
             socket.assigns.form_state.form.errors
             |> Keyword.get_values(:color)
             |> Enum.map(&elem(&1, 0))
  end

  test "a save with a value the type refuses writes nothing and shows the type's message" do
    socket = event(mount(), "save", %{"color" => "red"})

    assert Ash.read!(ColoredEntry) == []
    assert socket.assigns.form_state.errors[:color] == ["must be a hex colour"]
  end

  test "a save with a value the type accepts is written" do
    event(mount(), "save", %{"color" => "#ff0000"})

    assert [%{color: "#ff0000"}] = Ash.read!(ColoredEntry)
  end
end
