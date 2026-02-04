defmodule MishkaGervaz.Table.Web.RefreshTest do
  @moduledoc """
  Tests for the Refresh module runtime functionality.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Refresh

  # Helper to create a mock socket with assigns
  defp mock_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}}, assigns)
    }
  end

  describe "default_config/0" do
    test "returns default configuration map" do
      config = Refresh.default_config()

      assert config.enabled == false
      assert config.interval == 30_000
      assert config.pause_on_interaction == true
      assert config.show_indicator == true
      assert config.pause_on_blur == true
    end

    test "returns a map with all expected keys" do
      config = Refresh.default_config()

      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :interval)
      assert Map.has_key?(config, :pause_on_interaction)
      assert Map.has_key?(config, :show_indicator)
      assert Map.has_key?(config, :pause_on_blur)
    end
  end

  describe "refresh_message/0" do
    test "returns the refresh message atom" do
      assert Refresh.refresh_message() == :gervaz_refresh
    end
  end

  describe "init/1" do
    test "initializes refresh_timer as nil" do
      socket = mock_socket()
      result = Refresh.init(socket)

      assert result.assigns.refresh_timer == nil
    end

    test "initializes refresh_paused as false" do
      socket = mock_socket()
      result = Refresh.init(socket)

      assert result.assigns.refresh_paused == false
    end

    test "initializes refresh_last_at as nil" do
      socket = mock_socket()
      result = Refresh.init(socket)

      assert result.assigns.refresh_last_at == nil
    end

    test "schedules refresh when config is enabled" do
      socket = mock_socket(%{refresh_config: %{enabled: true, interval: 100}})
      result = Refresh.init(socket)

      assert result.assigns.refresh_timer != nil
      assert is_reference(result.assigns.refresh_timer)

      # Cleanup
      Process.cancel_timer(result.assigns.refresh_timer)
    end

    test "does not schedule refresh when config is disabled" do
      socket = mock_socket(%{refresh_config: %{enabled: false, interval: 100}})
      result = Refresh.init(socket)

      assert result.assigns.refresh_timer == nil
    end

    test "does not schedule refresh when no config present" do
      socket = mock_socket()
      result = Refresh.init(socket)

      assert result.assigns.refresh_timer == nil
    end
  end

  describe "schedule/2" do
    test "schedules timer when enabled" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 100}

      result = Refresh.schedule(socket, config)

      assert result.assigns.refresh_timer != nil
      assert is_reference(result.assigns.refresh_timer)

      # Cleanup
      Process.cancel_timer(result.assigns.refresh_timer)
    end

    test "sets refresh_last_at to current time" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 100}

      before = DateTime.utc_now()
      result = Refresh.schedule(socket, config)
      after_time = DateTime.utc_now()

      assert result.assigns.refresh_last_at != nil
      assert DateTime.compare(result.assigns.refresh_last_at, before) in [:gt, :eq]
      assert DateTime.compare(result.assigns.refresh_last_at, after_time) in [:lt, :eq]

      # Cleanup
      Process.cancel_timer(result.assigns.refresh_timer)
    end

    test "does not schedule when disabled" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: false, interval: 100}

      result = Refresh.schedule(socket, config)

      assert result.assigns.refresh_timer == nil
    end

    test "does not schedule when paused" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})
      config = %{enabled: true, interval: 100}

      result = Refresh.schedule(socket, config)

      assert result.assigns.refresh_timer == nil
    end

    test "cancels existing timer before scheduling new one" do
      # Create initial timer
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}
      socket_with_timer = Refresh.schedule(socket, config)
      old_timer = socket_with_timer.assigns.refresh_timer

      # Schedule again
      result = Refresh.schedule(socket_with_timer, config)
      new_timer = result.assigns.refresh_timer

      # Old timer should be cancelled (returns false when already cancelled)
      assert Process.cancel_timer(old_timer) == false
      # New timer should be active
      assert is_integer(Process.cancel_timer(new_timer))
    end

    test "uses default config values when partial config provided" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true}

      result = Refresh.schedule(socket, config)

      assert result.assigns.refresh_timer != nil

      # Cleanup
      Process.cancel_timer(result.assigns.refresh_timer)
    end

    test "handles nil config gracefully" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})

      result = Refresh.schedule(socket, nil)

      # Should use default config which has enabled: false
      assert result.assigns[:refresh_timer] == nil
    end
  end

  describe "pause/1" do
    test "cancels existing timer" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}
      socket_with_timer = Refresh.schedule(socket, config)
      timer_ref = socket_with_timer.assigns.refresh_timer

      result = Refresh.pause(socket_with_timer)

      # Timer should be cancelled
      assert Process.cancel_timer(timer_ref) == false
      assert result.assigns.refresh_timer == nil
    end

    test "sets refresh_paused to true" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})

      result = Refresh.pause(socket)

      assert result.assigns.refresh_paused == true
    end

    test "sets refresh_timer to nil" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}
      socket_with_timer = Refresh.schedule(socket, config)

      result = Refresh.pause(socket_with_timer)

      assert result.assigns.refresh_timer == nil
    end

    test "handles socket without timer gracefully" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})

      result = Refresh.pause(socket)

      assert result.assigns.refresh_timer == nil
      assert result.assigns.refresh_paused == true
    end
  end

  describe "resume/2" do
    test "sets refresh_paused to false" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})
      config = %{enabled: true, interval: 100}

      result = Refresh.resume(socket, config)

      assert result.assigns.refresh_paused == false

      # Cleanup
      if result.assigns.refresh_timer, do: Process.cancel_timer(result.assigns.refresh_timer)
    end

    test "schedules new timer when enabled" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})
      config = %{enabled: true, interval: 100}

      result = Refresh.resume(socket, config)

      assert result.assigns.refresh_timer != nil
      assert is_reference(result.assigns.refresh_timer)

      # Cleanup
      Process.cancel_timer(result.assigns.refresh_timer)
    end

    test "does not schedule timer when disabled" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})
      config = %{enabled: false, interval: 100}

      result = Refresh.resume(socket, config)

      assert result.assigns.refresh_paused == false
      assert result.assigns.refresh_timer == nil
    end
  end

  describe "stop/1" do
    test "cancels existing timer" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}
      socket_with_timer = Refresh.schedule(socket, config)
      timer_ref = socket_with_timer.assigns.refresh_timer

      result = Refresh.stop(socket_with_timer)

      # Timer should be cancelled
      assert Process.cancel_timer(timer_ref) == false
      assert result.assigns.refresh_timer == nil
    end

    test "sets refresh_timer to nil" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}
      socket_with_timer = Refresh.schedule(socket, config)

      result = Refresh.stop(socket_with_timer)

      assert result.assigns.refresh_timer == nil
    end

    test "sets refresh_paused to false" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})

      result = Refresh.stop(socket)

      assert result.assigns.refresh_paused == false
    end

    test "handles socket without timer gracefully" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})

      result = Refresh.stop(socket)

      assert result.assigns.refresh_timer == nil
      assert result.assigns.refresh_paused == false
    end
  end

  describe "active?/1" do
    test "returns true when timer exists and not paused" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}
      socket_with_timer = Refresh.schedule(socket, config)

      assert Refresh.active?(socket_with_timer) == true

      # Cleanup
      Process.cancel_timer(socket_with_timer.assigns.refresh_timer)
    end

    test "returns false when timer is nil" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})

      assert Refresh.active?(socket) == false
    end

    test "returns false when paused even with timer" do
      socket = mock_socket(%{refresh_timer: make_ref(), refresh_paused: true})

      assert Refresh.active?(socket) == false
    end

    test "returns false when both timer nil and paused" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})

      assert Refresh.active?(socket) == false
    end
  end

  describe "paused?/1" do
    test "returns true when refresh_paused is true" do
      socket = mock_socket(%{refresh_paused: true})

      assert Refresh.paused?(socket) == true
    end

    test "returns false when refresh_paused is false" do
      socket = mock_socket(%{refresh_paused: false})

      assert Refresh.paused?(socket) == false
    end

    test "returns false when refresh_paused is nil" do
      socket = mock_socket(%{refresh_paused: nil})

      assert Refresh.paused?(socket) == false
    end

    test "returns false when refresh_paused key is missing" do
      socket = mock_socket(%{})

      assert Refresh.paused?(socket) == false
    end
  end

  describe "time_until_next/2" do
    test "returns nil when refresh_last_at is nil" do
      socket = mock_socket(%{refresh_last_at: nil})
      config = %{interval: 30_000}

      assert Refresh.time_until_next(socket, config) == nil
    end

    test "returns remaining time when refresh_last_at is set" do
      socket = mock_socket(%{refresh_last_at: DateTime.utc_now()})
      config = %{interval: 30_000}

      result = Refresh.time_until_next(socket, config)

      assert result != nil
      # Use assert_in_delta for timing-sensitive tests (tolerance of 500ms)
      assert_in_delta result, 30_000, 500
    end

    test "returns 0 when interval has passed" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      socket = mock_socket(%{refresh_last_at: past})
      config = %{interval: 30_000}

      result = Refresh.time_until_next(socket, config)

      assert result == 0
    end

    test "calculates remaining time proportionally" do
      # Set last refresh to 10 seconds ago
      past = DateTime.add(DateTime.utc_now(), -10, :second)
      socket = mock_socket(%{refresh_last_at: past})
      config = %{interval: 30_000}

      result = Refresh.time_until_next(socket, config)

      # Should be around 20 seconds (20_000 ms) remaining
      # Use assert_in_delta with 500ms tolerance for timing variance
      assert_in_delta result, 20_000, 500
    end

    test "uses default interval when not specified in config" do
      socket = mock_socket(%{refresh_last_at: DateTime.utc_now()})
      config = %{}

      result = Refresh.time_until_next(socket, config)

      assert result != nil
      # Default interval is 30_000, use tolerance for timing
      assert_in_delta result, 30_000, 500
    end
  end

  describe "indicator_assigns/2" do
    test "returns map with active? key" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false, refresh_last_at: nil})
      config = %{interval: 30_000, show_indicator: true}

      result = Refresh.indicator_assigns(socket, config)

      assert Map.has_key?(result, :active?)
      assert result.active? == false
    end

    test "returns map with paused? key" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true, refresh_last_at: nil})
      config = %{interval: 30_000, show_indicator: true}

      result = Refresh.indicator_assigns(socket, config)

      assert Map.has_key?(result, :paused?)
      assert result.paused? == true
    end

    test "returns map with interval key" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false, refresh_last_at: nil})
      config = %{interval: 45_000, show_indicator: true}

      result = Refresh.indicator_assigns(socket, config)

      assert Map.has_key?(result, :interval)
      assert result.interval == 45_000
    end

    test "returns map with next_in key" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false, refresh_last_at: nil})
      config = %{interval: 30_000, show_indicator: true}

      result = Refresh.indicator_assigns(socket, config)

      assert Map.has_key?(result, :next_in)
      assert result.next_in == nil
    end

    test "returns map with show? key" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false, refresh_last_at: nil})
      config = %{interval: 30_000, show_indicator: true}

      result = Refresh.indicator_assigns(socket, config)

      assert Map.has_key?(result, :show?)
      assert result.show? == true
    end

    test "show? reflects show_indicator config" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false, refresh_last_at: nil})
      config = %{interval: 30_000, show_indicator: false}

      result = Refresh.indicator_assigns(socket, config)

      assert result.show? == false
    end

    test "correctly reflects active state with timer" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000, show_indicator: true}
      socket_with_timer = Refresh.schedule(socket, config)

      result = Refresh.indicator_assigns(socket_with_timer, config)

      assert result.active? == true
      assert result.paused? == false

      # Cleanup
      Process.cancel_timer(socket_with_timer.assigns.refresh_timer)
    end

    test "calculates next_in when refresh_last_at is set" do
      socket =
        mock_socket(%{
          refresh_timer: make_ref(),
          refresh_paused: false,
          refresh_last_at: DateTime.utc_now()
        })

      config = %{interval: 30_000, show_indicator: true}

      result = Refresh.indicator_assigns(socket, config)

      assert result.next_in != nil
      assert_in_delta result.next_in, 30_000, 500
    end
  end

  describe "timer message delivery" do
    test "scheduled timer sends refresh message to self" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 50}

      socket_with_timer = Refresh.schedule(socket, config)

      # Wait for timer to fire
      assert_receive :gervaz_refresh, 200

      # Timer ref should still exist in socket (it's a snapshot)
      assert socket_with_timer.assigns.refresh_timer != nil
    end

    test "cancelled timer does not send message" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 100}

      socket_with_timer = Refresh.schedule(socket, config)
      Refresh.pause(socket_with_timer)

      # Wait and verify no message
      refute_receive :gervaz_refresh, 200
    end

    test "stopped timer does not send message" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 100}

      socket_with_timer = Refresh.schedule(socket, config)
      Refresh.stop(socket_with_timer)

      # Wait and verify no message
      refute_receive :gervaz_refresh, 200
    end
  end

  describe "pause and resume workflow" do
    test "pause then resume restarts timer" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}

      # Initial schedule
      socket = Refresh.schedule(socket, config)
      assert Refresh.active?(socket)

      # Pause
      socket = Refresh.pause(socket)
      assert Refresh.paused?(socket)
      refute Refresh.active?(socket)

      # Resume
      socket = Refresh.resume(socket, config)
      refute Refresh.paused?(socket)
      assert Refresh.active?(socket)

      # Cleanup
      Process.cancel_timer(socket.assigns.refresh_timer)
    end

    test "multiple pause calls are idempotent" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true, interval: 5000}

      socket = Refresh.schedule(socket, config)
      socket = Refresh.pause(socket)
      socket = Refresh.pause(socket)
      socket = Refresh.pause(socket)

      assert Refresh.paused?(socket)
      assert socket.assigns.refresh_timer == nil
    end

    test "multiple resume calls are safe" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: true})
      config = %{enabled: true, interval: 5000}

      socket = Refresh.resume(socket, config)
      timer1 = socket.assigns.refresh_timer

      socket = Refresh.resume(socket, config)
      timer2 = socket.assigns.refresh_timer

      # Each resume schedules a new timer (old one cancelled)
      assert timer1 != timer2
      refute Refresh.paused?(socket)

      # Cleanup
      Process.cancel_timer(socket.assigns.refresh_timer)
    end
  end

  describe "init then schedule workflow" do
    test "init with enabled config schedules automatically" do
      socket = mock_socket(%{refresh_config: %{enabled: true, interval: 5000}})

      socket = Refresh.init(socket)

      assert Refresh.active?(socket)
      assert socket.assigns.refresh_timer != nil

      # Cleanup
      Process.cancel_timer(socket.assigns.refresh_timer)
    end

    test "init with disabled config does not schedule" do
      socket = mock_socket(%{refresh_config: %{enabled: false, interval: 5000}})

      socket = Refresh.init(socket)

      refute Refresh.active?(socket)
      assert socket.assigns.refresh_timer == nil
    end

    test "schedule after init replaces timer" do
      socket = mock_socket(%{refresh_config: %{enabled: true, interval: 5000}})
      config = %{enabled: true, interval: 10_000}

      socket = Refresh.init(socket)
      old_timer = socket.assigns.refresh_timer

      socket = Refresh.schedule(socket, config)
      new_timer = socket.assigns.refresh_timer

      assert old_timer != new_timer
      assert Process.cancel_timer(old_timer) == false

      # Cleanup
      Process.cancel_timer(socket.assigns.refresh_timer)
    end
  end

  describe "edge cases" do
    test "handles missing assigns gracefully in active?" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

      # Should not raise, returns false
      assert Refresh.active?(socket) == false
    end

    test "handles missing assigns gracefully in paused?" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

      # Should not raise, returns false
      assert Refresh.paused?(socket) == false
    end

    test "handles empty config map in schedule" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})

      result = Refresh.schedule(socket, %{})

      # Uses defaults, enabled: false by default
      assert result.assigns[:refresh_timer] == nil
    end

    test "handles config with only enabled key" do
      socket = mock_socket(%{refresh_timer: nil, refresh_paused: false})
      config = %{enabled: true}

      result = Refresh.schedule(socket, config)

      # Should use default interval
      assert result.assigns.refresh_timer != nil

      # Cleanup
      Process.cancel_timer(result.assigns.refresh_timer)
    end
  end
end
