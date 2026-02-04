defmodule MishkaGervaz.Table.Web.Refresh do
  @moduledoc """
  Auto-refresh functionality for MishkaGervaz tables.

  Provides automatic data reloading at configurable intervals with
  intelligent pausing during user interactions.

  ## Configuration

  Enable in domain table config:

      mishka_gervaz do
        table do
          refresh do
            enabled true
            interval 30_000  # 30 seconds
            pause_on_interaction true
            show_indicator true
            pause_on_blur true
          end
        end
      end

  ## Usage in LiveComponent

  The table LiveComponent integrates with this module:

      def mount(socket) do
        socket =
          socket
          |> assign(:refresh_config, get_refresh_config())
          |> Refresh.init()

        {:ok, socket}
      end

      def handle_info(:gervaz_refresh, socket) do
        socket =
          socket
          |> reload_data()
          |> Refresh.schedule(socket.assigns.refresh_config)

        {:noreply, socket}
      end

      def handle_event("filter", params, socket) do
        # Pause refresh during interaction
        socket = Refresh.pause(socket)

        # ... handle filter ...

        # Resume after interaction
        socket = Refresh.resume(socket, socket.assigns.refresh_config)
        {:noreply, socket}
      end

  ## Client-side Integration

  For `pause_on_blur`, add this to your app.js:

      window.addEventListener("blur", () => {
        document.querySelectorAll("[data-gervaz-refresh]").forEach(el => {
          el.dispatchEvent(new CustomEvent("gervaz:pause_refresh"))
        })
      })

      window.addEventListener("focus", () => {
        document.querySelectorAll("[data-gervaz-refresh]").forEach(el => {
          el.dispatchEvent(new CustomEvent("gervaz:resume_refresh"))
        })
      })
  """

  import Phoenix.Component, only: [assign: 3]

  @refresh_message :gervaz_refresh

  @default_config %{
    enabled: false,
    interval: 30_000,
    pause_on_interaction: true,
    show_indicator: true,
    pause_on_blur: true
  }

  @doc """
  Initialize refresh state in socket.

  Call this in `mount/1`:

      socket
      |> assign(:refresh_config, config)
      |> Refresh.init()
  """
  @spec init(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def init(socket) do
    socket
    |> assign(:refresh_timer, nil)
    |> assign(:refresh_paused, false)
    |> assign(:refresh_last_at, nil)
    |> maybe_schedule_initial()
  end

  @doc """
  Schedule the next refresh.

  Call this after handling `@refresh_message`:

      def handle_info(:gervaz_refresh, socket) do
        socket =
          socket
          |> reload_data()
          |> Refresh.schedule(socket.assigns.refresh_config)

        {:noreply, socket}
      end
  """
  @spec schedule(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def schedule(socket, config) do
    config = merge_config(config)

    if config.enabled and not socket.assigns[:refresh_paused] do
      cancel_existing(socket)
      timer_ref = Process.send_after(self(), @refresh_message, config.interval)

      socket
      |> assign(:refresh_timer, timer_ref)
      |> assign(:refresh_last_at, DateTime.utc_now())
    else
      socket
    end
  end

  @doc """
  Pause auto-refresh.

  Call this when user starts interacting:

      def handle_event("filter", _params, socket) do
        socket = Refresh.pause(socket)
        # ... handle filter
      end
  """
  @spec pause(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def pause(socket) do
    cancel_existing(socket)

    socket
    |> assign(:refresh_timer, nil)
    |> assign(:refresh_paused, true)
  end

  @doc """
  Resume auto-refresh after pause.

  Call this when user finishes interacting:

      socket
      |> Refresh.resume(socket.assigns.refresh_config)
  """
  @spec resume(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def resume(socket, config) do
    socket
    |> assign(:refresh_paused, false)
    |> schedule(config)
  end

  @doc """
  Stop auto-refresh completely.

  Call this in `terminate/2` or when disabling:

      Refresh.stop(socket)
  """
  @spec stop(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def stop(socket) do
    cancel_existing(socket)

    socket
    |> assign(:refresh_timer, nil)
    |> assign(:refresh_paused, false)
  end

  @doc """
  Check if refresh is currently active.
  """
  @spec active?(Phoenix.LiveView.Socket.t()) :: boolean()
  def active?(socket) do
    socket.assigns[:refresh_timer] != nil and not socket.assigns[:refresh_paused]
  end

  @doc """
  Check if refresh is paused.
  """
  @spec paused?(Phoenix.LiveView.Socket.t()) :: boolean()
  def paused?(socket) do
    socket.assigns[:refresh_paused] == true
  end

  @doc """
  Get time until next refresh in milliseconds.

  Returns `nil` if refresh is not scheduled.
  """
  @spec time_until_next(Phoenix.LiveView.Socket.t(), map()) :: non_neg_integer() | nil
  def time_until_next(socket, config) do
    config = merge_config(config)

    case socket.assigns[:refresh_last_at] do
      nil ->
        nil

      last_at ->
        elapsed = DateTime.diff(DateTime.utc_now(), last_at, :millisecond)
        remaining = config.interval - elapsed
        max(0, remaining)
    end
  end

  @doc """
  Get the refresh message atom used for `handle_info`.
  """
  @spec refresh_message() :: atom()
  def refresh_message, do: @refresh_message

  @doc """
  Get default refresh configuration.
  """
  @spec default_config() :: map()
  def default_config, do: @default_config

  @doc """
  Build refresh indicator assigns for templates.

  Returns a map with:
  - `active?` - whether refresh is active
  - `paused?` - whether refresh is paused
  - `interval` - refresh interval in ms
  - `next_in` - time until next refresh in ms
  """
  @spec indicator_assigns(Phoenix.LiveView.Socket.t(), map()) :: map()
  def indicator_assigns(socket, config) do
    config = merge_config(config)

    %{
      active?: active?(socket),
      paused?: paused?(socket),
      interval: config.interval,
      next_in: time_until_next(socket, config),
      show?: config.show_indicator
    }
  end

  @spec maybe_schedule_initial(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp maybe_schedule_initial(socket) do
    config = socket.assigns[:refresh_config] || @default_config

    if config[:enabled] do
      schedule(socket, config)
    else
      socket
    end
  end

  @spec cancel_existing(Phoenix.LiveView.Socket.t()) :: :ok | non_neg_integer() | false
  defp cancel_existing(socket) do
    case socket.assigns[:refresh_timer] do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end
  end

  @spec merge_config(map() | any()) :: map()
  defp merge_config(config) when is_map(config) do
    Map.merge(@default_config, config)
  end

  defp merge_config(_), do: @default_config
end
