defmodule MishkaGervaz.Table.Types.Column.Badge do
  @moduledoc """
  Badge/Status column type.

  Renders values as colored badges.

  ## Options (via column.ui.extra)

  - `:colors` - Map of value to color class
    Example: %{draft: "bg-gray-100 text-gray-800", published: "bg-green-100 text-green-800"}
  - `:default_color` - Default color if value not in map (default: "bg-gray-100 text-gray-800")
  - `:labels` - Map of value to display label (default: humanizes the value)
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component
  import MishkaGervaz.Helpers, only: [humanize: 1]

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)
    colors = extra[:colors] || %{}
    labels = extra[:labels] || %{}
    value_key = normalize_key(value)

    color = Map.get(colors, value_key, extra[:default_color])
    label = Map.get(labels, value_key, humanize(value))

    ui.badge(%{__changed__: %{}, label: label, class: color})
  end

  @spec normalize_key(term()) :: atom()
  defp normalize_key(value) when is_atom(value), do: value
  defp normalize_key(value) when is_binary(value), do: String.to_atom(value)
  defp normalize_key(value), do: to_string(value) |> String.to_atom()

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
