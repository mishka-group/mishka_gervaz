defmodule MishkaGervaz.Form.Web.FieldDefaultTest do
  @moduledoc """
  A field's `default` is the value a create form starts with: drawn in its input and saved when the
  author leaves it. A value the mount's `defaults` gives the field is saved instead, and an edit
  shows the record's own value.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Live}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Test.Resources.DefaultedEntry

  @user %{id: "user-1", site_id: nil}

  setup do
    DefaultedEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp mount(assigns \\ %{}) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        Map.merge(
          %{id: "defaulted-entry", resource: DefaultedEntry, current_user: @user},
          assigns
        ),
        socket
      )

    socket
  end

  defp value(socket, field),
    do: Phoenix.HTML.Form.input_value(socket.assigns.form_state.form, field)

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  test "a create form starts with each field's default" do
    socket = mount()

    assert value(socket, :title) == "Untitled"
    assert value(socket, :status) == "published"
  end

  test "a default the author leaves is saved" do
    socket = mount()

    save(socket, socket.assigns.form_state.form.params)

    assert [%{title: "Untitled", status: "published"}] = Ash.read!(DefaultedEntry)
  end

  test "what the author types replaces the default" do
    mount() |> save(%{"title" => "Mine", "status" => "draft"})

    assert [%{title: "Mine", status: "draft"}] = Ash.read!(DefaultedEntry)
  end

  test "a value the mount's defaults give the field is saved instead" do
    socket = mount(%{defaults: %{title: "From the page"}})

    save(socket, socket.assigns.form_state.form.params)

    assert [%{title: "From the page", status: "published"}] = Ash.read!(DefaultedEntry)
  end

  test "an edit shows the record's own value" do
    entry = Ash.create!(DefaultedEntry, %{title: "Saved", status: "draft"})
    socket = mount()

    socket =
      Live.update(%{id: "defaulted-entry", record_id: entry.id, reset: true}, socket) |> elem(1)

    {:ok, form} =
      RecordLoader.Default.load_for_edit(socket.assigns.form_state, entry.id, actor: @user)

    socket = DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

    assert value(socket, :title) == "Saved"
    assert value(socket, :status) == "draft"
  end
end
