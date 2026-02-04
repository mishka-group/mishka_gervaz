defmodule MishkaGervaz.Table.Types.Column.DateTime do
  @moduledoc """
  DateTime column type.

  Renders DateTime values with customizable formatting.

  ## Options (via column.ui.extra)

  - `:format` - DateTime format string (default: "%Y-%m-%d %H:%M")
  - `:relative` - Show relative time like "2 hours ago" (default: false)
  - `:timezone` - Convert to timezone (default: nil, shows as-is)
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @default_format "%Y-%m-%d %H:%M"

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(%DateTime{} = value, column, _record, ui) do
    extra = get_extra(column)

    if extra[:relative] do
      render_relative(value, extra, ui)
    else
      format = extra[:format] || @default_format
      formatted = Calendar.strftime(value, format)

      ui.cell_datetime(%{
        __changed__: %{},
        formatted: formatted,
        iso: DateTime.to_iso8601(value),
        variant: :default,
        class: extra[:class]
      })
    end
  end

  def render(%NaiveDateTime{} = value, column, record, ui) do
    value
    |> DateTime.from_naive!("Etc/UTC")
    |> render(column, record, ui)
  end

  def render(value, column, record, ui) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> render(datetime, column, record, ui)
      _ -> render_raw(value, column, ui)
    end
  end

  def render(value, column, _record, ui) do
    render_raw(to_string(value), column, ui)
  end

  @spec render_relative(DateTime.t(), map(), module()) :: Phoenix.LiveView.Rendered.t()
  defp render_relative(datetime, extra, ui) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)
    relative = format_relative(diff_seconds)

    ui.cell_datetime(%{
      __changed__: %{},
      formatted: relative,
      iso: DateTime.to_iso8601(datetime),
      variant: :relative,
      class: extra[:class]
    })
  end

  @spec format_relative(integer()) :: String.t()
  defp format_relative(seconds) when seconds < 0 do
    format_future(-seconds)
  end

  defp format_relative(seconds) do
    format_past(seconds)
  end

  @spec format_past(non_neg_integer()) :: String.t()
  defp format_past(seconds) when seconds < 60, do: "just now"
  defp format_past(seconds) when seconds < 3600, do: "#{div(seconds, 60)} min ago"
  defp format_past(seconds) when seconds < 86400, do: "#{div(seconds, 3600)} hours ago"
  defp format_past(seconds) when seconds < 604_800, do: "#{div(seconds, 86400)} days ago"
  defp format_past(seconds) when seconds < 2_592_000, do: "#{div(seconds, 604_800)} weeks ago"
  defp format_past(seconds), do: "#{div(seconds, 2_592_000)} months ago"

  @spec format_future(non_neg_integer()) :: String.t()
  defp format_future(seconds) when seconds < 60, do: "in a moment"
  defp format_future(seconds) when seconds < 3600, do: "in #{div(seconds, 60)} min"
  defp format_future(seconds) when seconds < 86400, do: "in #{div(seconds, 3600)} hours"
  defp format_future(seconds), do: "in #{div(seconds, 86400)} days"

  @spec render_raw(String.t(), map(), module()) :: Phoenix.LiveView.Rendered.t()
  defp render_raw(value, column, ui) do
    extra = get_extra(column)

    ui.cell_datetime(%{
      __changed__: %{},
      formatted: value,
      iso: nil,
      variant: :default,
      class: extra[:class]
    })
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
