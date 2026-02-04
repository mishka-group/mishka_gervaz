defmodule MishkaGervaz.Table.Types.Column.Date do
  @moduledoc """
  Date column type.

  Renders Date values with customizable formatting.

  ## Options (via column.ui.extra)

  - `:format` - Date format string (default: "%Y-%m-%d")
    Common formats:
    - "%Y-%m-%d" → 2024-01-15
    - "%d/%m/%Y" → 15/01/2024
    - "%B %d, %Y" → January 15, 2024
    - "%b %d" → Jan 15
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @default_format "%Y-%m-%d"

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(%Date{} = value, column, _record, ui) do
    extra = get_extra(column)
    format = extra[:format] || @default_format
    formatted = Calendar.strftime(value, format)

    ui.cell_date(%{
      __changed__: %{},
      formatted: formatted,
      class: extra[:class]
    })
  end

  def render(value, column, record, ui) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> render(date, column, record, ui)
      _ -> render_raw(value, column, ui)
    end
  end

  def render(value, column, _record, ui) do
    render_raw(to_string(value), column, ui)
  end

  @spec render_raw(String.t(), map(), module()) :: Phoenix.LiveView.Rendered.t()
  defp render_raw(value, column, ui) do
    extra = get_extra(column)
    ui.cell_date(%{__changed__: %{}, formatted: value, class: extra[:class]})
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
