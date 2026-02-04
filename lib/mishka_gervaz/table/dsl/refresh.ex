defmodule MishkaGervaz.Table.Dsl.Refresh do
  @moduledoc """
  DSL section for auto-refresh configuration at the resource level.

  This allows overriding domain-level refresh defaults for specific resources.

  ## Example

      mishka_gervaz do
        table do
          refresh do
            enabled true
            interval 15_000  # Override domain default of 30s
          end
        end
      end

  ## Options

  - `enabled` - Enable/disable auto-refresh for this resource
  - `interval` - Refresh interval in milliseconds
  - `pause_on_interaction` - Pause refresh when user is interacting
  - `show_indicator` - Show visual refresh indicator
  - `pause_on_blur` - Pause when browser tab loses focus
  """

  @schema [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable auto-refresh for this resource. Overrides domain default."
    ],
    interval: [
      type: :pos_integer,
      doc: "Refresh interval in milliseconds. Overrides domain default."
    ],
    pause_on_interaction: [
      type: :boolean,
      doc: "Pause auto-refresh when user is interacting. Overrides domain default."
    ],
    show_indicator: [
      type: :boolean,
      doc: "Show visual indicator when auto-refresh is active. Overrides domain default."
    ],
    pause_on_blur: [
      type: :boolean,
      doc: "Pause auto-refresh when browser tab loses focus. Overrides domain default."
    ]
  ]

  @doc """
  Returns the refresh section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :refresh,
      describe: "Auto-refresh configuration. Overrides domain defaults if set.",
      schema: @schema
    }
  end
end
