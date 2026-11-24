defmodule MishkaGervaz.Test.Web.ToastPageLive do
  @moduledoc """
  A page that keeps its toasts with `MishkaGervaz.Toast` (`attach/1` on mount) and draws them with
  `MishkaGervaz.Toast.toasts/1`. Its buttons push them:

    * `#saved` — "Saved.", in the ok tone;
    * `#brief` — "Copied.", with `ms: 0`, so its time is up at once;
    * `#deleted` — "Item deleted.", in the info tone, with an Undo that stands for `"item-42"`;
      the page shows what an Undo handed it in `#undone`;
    * `#exported` — "Your file is ready.", with a link to a file;
    * `#counted` — "Saved 1.", "Saved 2.", ..., a new sentence on each press;
    * `#from-component` — a button in `MishkaGervaz.Test.Web.ToastPageLive.Saver`, a component that
      sends "Could not save." in the error tone with `MishkaGervaz.Toast.send_toast/3`.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Toast

  defmodule Saver do
    @moduledoc "A component of the page whose button sends a toast with `Toast.send_toast/3`."
    use Phoenix.LiveComponent

    @impl true
    def handle_event("save", _params, socket) do
      MishkaGervaz.Toast.send_toast(:error, "Could not save.")
      {:noreply, socket}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        <button id="from-component" type="button" phx-click="save" phx-target={@myself}>
          Save
        </button>
      </div>
      """
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    new_socket =
      socket
      |> assign(undone: nil, count: 0)
      |> Toast.attach()

    {:ok, new_socket}
  end

  @impl true
  def handle_event("saved", _params, socket), do: {:noreply, Toast.push(socket, :ok, "Saved.")}

  def handle_event("brief", _params, socket),
    do: {:noreply, Toast.push(socket, :ok, "Copied.", ms: 0)}

  def handle_event("counted", _params, socket) do
    count = socket.assigns.count + 1
    new_socket = socket |> assign(:count, count) |> Toast.push(:ok, "Saved #{count}.")
    {:noreply, new_socket}
  end

  def handle_event("deleted", _params, socket),
    do: {:noreply, Toast.push(socket, :info, "Item deleted.", undo: "item-42")}

  def handle_event("exported", _params, socket),
    do:
      {:noreply,
       Toast.push(socket, :ok, "Your file is ready.",
         href: "/exports/1.csv",
         link_label: "Download"
       )}

  @impl true
  def handle_info({:toast_undo, undo}, socket), do: {:noreply, assign(socket, :undone, undo)}

  @impl true
  def render(assigns) do
    ~H"""
    <p id="undone">{@undone}</p>
    <button :for={id <- ~w(saved brief deleted exported counted)} id={id} type="button" phx-click={id}>
      {id}
    </button>
    <.live_component module={Saver} id="saver" />
    <Toast.toasts toasts={@gervaz_toasts} />
    """
  end
end
