defmodule MishkaGervaz.Toast do
  @moduledoc """
  Short notes a LiveView page shows at the bottom of the screen after something happened, "Order
  refunded.", each in a tone, with an optional Undo and an optional link, drawn by the UI adapter's
  `toast/1`. They leave by themselves: the page's own process takes each one away when its time is
  up, with a timer message, so nothing in them is JavaScript.

  A page puts the hook that keeps them on its socket once, and draws them:

      def mount(_params, _session, socket), do: {:ok, MishkaGervaz.Toast.attach(socket)}

      def render(assigns) do
        ~H\"\"\"
        ...
        <MishkaGervaz.Toast.toasts toasts={@gervaz_toasts} ui={MyAppWeb.UIAdapter} />
        \"\"\"
      end

  Then pushes one where something happened:

      MishkaGervaz.Toast.push(socket, :ok, "Order refunded.",
        navigate: "/admin/refunds",
        link_label: "See refunds"
      )

      MishkaGervaz.Toast.push(socket, :info, "Product deleted.", undo: {:restore, product.id})

  A LiveComponent of the page, which runs in the page's process, sends one with `send_toast/3`.
  An Undo takes its toast away and sends the page `{:toast_undo, undo}`, where `undo` is the term
  the push gave; the page's `handle_info/2` does what it stands for.

  The toasts are kept in the socket's `:gervaz_toasts` assign, the newest last, at most four. A
  toast with the same words as one already shown takes its place, so a button pressed twice shows
  its sentence once, with its time starting again. A toast stays 5 seconds, 8 with an Undo or a
  link; `ms:` sets its own time.
  """

  use Phoenix.Component
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers, only: [dynamic_component: 1]

  @max 4
  @tones [:ok, :info, :warn, :error]

  @typedoc "A toast as the page keeps it."
  @type t :: %{
          id: pos_integer(),
          tone: :ok | :info | :warn | :error,
          text: String.t(),
          undo: term(),
          undo_label: String.t() | nil,
          navigate: String.t() | nil,
          href: String.t() | nil,
          link_label: String.t() | nil
        }

  @doc """
  Puts the hook that keeps the page's toasts on its socket, and starts their list (the
  `:gervaz_toasts` assign). The hook takes a toast away when its time is up or its Close is
  pressed, answers its Undo by sending the page `{:toast_undo, undo}`, and shows a toast a
  component sent with `send_toast/3`. Run it once, in the page's `mount/3`.
  """
  @spec attach(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def attach(socket) do
    socket
    |> assign(:gervaz_toasts, list(socket))
    |> Phoenix.LiveView.attach_hook(:gervaz_toasts, :handle_info, &heard/2)
    |> Phoenix.LiveView.attach_hook(:gervaz_toasts, :handle_event, &pressed/3)
  end

  @doc """
  Shows a toast in `tone` (`:ok`, `:info`, `:warn`, `:error`) saying `text`. A toast already shown
  with the same `text` is taken away first, so the same sentence never stacks.

  ## Options
    * `:undo` - what its Undo button stands for, any term; no button without it. The page is sent
      `{:toast_undo, undo}` when it is pressed
    * `:undo_label` - the button's words (default "Undo")
    * `:navigate` - a path inside the app the toast links to
    * `:href` - a plain address it links to instead, such as a file to download
    * `:link_label` - the link's words (default "Open")
    * `:ms` - how long it stays, in milliseconds (default 5000, 8000 with an Undo or a link)
  """
  @spec push(Phoenix.LiveView.Socket.t(), atom(), String.t(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def push(socket, tone, text, opts \\ []) do
    toast = new(tone, text, opts)

    if Phoenix.LiveView.connected?(socket),
      do: Process.send_after(self(), {:gervaz_toast_expire, toast.id}, opts[:ms] || ms(toast))

    kept = Enum.reject(list(socket), &(&1.text == text))
    assign(socket, :gervaz_toasts, Enum.take(kept ++ [toast], -@max))
  end

  @doc """
  Sends the page a toast from a LiveComponent, which runs in the page's process; `attach/1`'s
  hook shows it as `push/4` would. Takes `push/4`'s arguments.
  """
  @spec send_toast(atom(), String.t(), keyword()) ::
          {:gervaz_toast, atom(), String.t(), keyword()}
  def send_toast(tone, text, opts \\ []), do: send(self(), {:gervaz_toast, tone, text, opts})

  @doc "Takes the toast `id` away."
  @spec dismiss(Phoenix.LiveView.Socket.t(), pos_integer()) :: Phoenix.LiveView.Socket.t()
  def dismiss(socket, id),
    do: assign(socket, :gervaz_toasts, Enum.reject(list(socket), &(&1.id == id)))

  @doc """
  Draws the page's toasts in a polite live region at the bottom of the screen, at its end side
  (above the bottom edge on a phone), each with the UI adapter's `toast/1`. The container is the
  one live region: a toast inside it is not a region of its own, so a screen reader reads it once.

  ## Attributes
    * `:toasts` - the toasts, the page's `@gervaz_toasts`
    * `:ui` - the UI adapter module (default `MishkaGervaz.UIAdapters.Tailwind`)
    * `:id` - the region's id (default `"gervaz-toasts"`); each toast is `"<id>-<toast id>"`
  """
  attr :toasts, :list, default: []
  attr :ui, :atom, default: MishkaGervaz.UIAdapters.Tailwind
  attr :id, :string, default: "gervaz-toasts"

  @spec toasts(map()) :: Phoenix.LiveView.Rendered.t()
  def toasts(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed bottom-6 end-6 z-[70] flex flex-col items-end gap-2 max-[640px]:bottom-4 max-[640px]:start-3 max-[640px]:end-3"
    >
      <.dynamic_component
        :for={toast <- @toasts || []}
        module={@ui}
        function={:toast}
        id={"#{@id}-#{toast.id}"}
        toast_id={toast.id}
        tone={toast.tone}
        text={toast.text}
        undo_label={toast.undo_label}
        navigate={toast.navigate}
        href={toast.href}
        link_label={toast.link_label}
      />
    </div>
    """
  end

  defp new(tone, text, opts) do
    link? = is_binary(opts[:navigate]) or is_binary(opts[:href])

    %{
      id: System.unique_integer([:positive, :monotonic]),
      tone: tone(tone),
      text: text,
      undo: opts[:undo],
      undo_label:
        if(Keyword.has_key?(opts, :undo),
          do: opts[:undo_label] || dgettext("mishka_gervaz", "Undo")
        ),
      navigate: opts[:navigate],
      href: opts[:href],
      link_label: if(link?, do: opts[:link_label] || dgettext("mishka_gervaz", "Open"))
    }
  end

  defp tone(tone) when tone in @tones, do: tone
  defp tone(:success), do: :ok
  defp tone(:warning), do: :warn
  defp tone(:danger), do: :error
  defp tone(_tone), do: :info

  defp ms(%{undo_label: label}) when is_binary(label), do: 8_000
  defp ms(%{link_label: label}) when is_binary(label), do: 8_000
  defp ms(_plain), do: 5_000

  defp heard({:gervaz_toast_expire, id}, socket), do: {:halt, dismiss(socket, id)}

  defp heard({:gervaz_toast, tone, text, opts}, socket),
    do: {:halt, push(socket, tone, text, opts)}

  defp heard(_other, socket), do: {:cont, socket}

  defp pressed("gervaz_toast_close", %{"id" => id}, socket) do
    {_toast, new_socket} = take(socket, id)
    {:halt, new_socket}
  end

  defp pressed("gervaz_toast_undo", %{"id" => id}, socket) do
    case take(socket, id) do
      {%{undo: undo}, socket} when not is_nil(undo) ->
        send(self(), {:toast_undo, undo})
        {:halt, socket}

      {_gone, socket} ->
        {:halt, socket}
    end
  end

  defp pressed(_event, _params, socket), do: {:cont, socket}

  defp take(socket, id) do
    case Integer.parse(to_string(id)) do
      {id, ""} -> {Enum.find(list(socket), &(&1.id == id)), dismiss(socket, id)}
      _not_a_toast -> {nil, socket}
    end
  end

  defp list(socket), do: Map.get(socket.assigns, :gervaz_toasts) || []
end
