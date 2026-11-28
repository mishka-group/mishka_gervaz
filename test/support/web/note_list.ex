defmodule MishkaGervaz.Test.Web.NoteList do
  @moduledoc """
  A live component holding a stream of notes, as a page's own table in a step of a form. It mounts
  with no note, and its `#<id>-add` button streams one into `#<id>-rows`. The rows it streamed are
  lost only when it is mounted again.
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    new_socket =
      socket
      |> assign(:count, 0)
      |> stream(:notes, [])

    {:ok, new_socket}
  end

  @impl true
  def handle_event("add_note", _params, socket) do
    count = socket.assigns.count + 1

    new_socket =
      socket
      |> assign(:count, count)
      |> stream_insert(:notes, %{id: count, text: "Note #{count}"})

    {:noreply, new_socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <button id={@id <> "-add"} type="button" phx-click="add_note" phx-target={@myself}>
        Add a note
      </button>
      <ul id={@id <> "-rows"} phx-update="stream">
        <li :for={{dom_id, note} <- @streams.notes} id={dom_id}>{note.text}</li>
      </ul>
    </div>
    """
  end
end
