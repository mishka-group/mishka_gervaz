defmodule MishkaGervaz.Form.Web.ClearedDefaultTest do
  @moduledoc """
  A mount's `defaults` fill a create form's text field, and a field the author empties is saved
  empty: the save does not fill it again from `defaults`. A default for a key the form draws no
  field for is still saved.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{Events, Live, Renderer}
  alias MishkaGervaz.Test.Resources.DescriptorEntry

  @user %{id: "user-1", site_id: nil}
  @defaults %{statement_descriptor: "MISHKA STORE", owner: "shop-1"}

  setup do
    DescriptorEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp mount do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        %{
          id: "descriptor-entry",
          resource: DescriptorEntry,
          current_user: @user,
          defaults: @defaults
        },
        socket
      )

    socket
  end

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  defp validate(socket, params) do
    {:noreply, socket} = Events.handle("validate", %{"form" => params}, socket)
    socket
  end

  defp drawn_value(socket, name) do
    html = render_component(&Renderer.render/1, %{form_state: socket.assigns.form_state})

    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s(input[name="form[#{name}]"]))
    |> LazyHTML.attribute("value")
    |> List.first("")
  end

  test "the field starts with the mount's default" do
    assert drawn_value(mount(), "statement_descriptor") == "MISHKA STORE"
  end

  test "a field the author leaves saves its default" do
    mount() |> save(%{"name" => "Shop", "statement_descriptor" => "MISHKA STORE"})

    assert [%{statement_descriptor: "MISHKA STORE", owner: "shop-1"}] =
             Ash.read!(DescriptorEntry)
  end

  test "a field the author empties saves empty" do
    mount()
    |> validate(%{"name" => "Shop", "statement_descriptor" => ""})
    |> save(%{"name" => "Shop", "statement_descriptor" => ""})

    assert [saved] = Ash.read!(DescriptorEntry)
    assert saved.statement_descriptor in [nil, ""]
    assert saved.owner == "shop-1"
  end

  test "the emptied field stays empty on the form" do
    socket = mount() |> validate(%{"name" => "Shop", "statement_descriptor" => ""})

    assert drawn_value(socket, "statement_descriptor") == ""
  end
end
