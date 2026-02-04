defmodule MishkaGervaz.Table.Types.Column.UUID do
  @moduledoc """
  UUID column type.

  Renders UUID values with truncation for display.

  ## Options (via column.ui.extra)

  - `:show_full` - Show full UUID (default: false)
  - `:prefix_length` - Characters to show at start (default: 8)
  - `:suffix_length` - Characters to show at end (default: 0)
  - `:copy_button` - Show copy button (default: false)
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)
    uuid_str = to_string(value)

    if extra[:show_full] do
      ui.cell_code(%{__changed__: %{}, value: uuid_str, class: extra[:class]})
    else
      prefix_len = extra[:prefix_length] || 8
      suffix_len = extra[:suffix_length] || 0
      display = truncate_uuid(uuid_str, prefix_len, suffix_len)
      ui.cell_code(%{__changed__: %{}, value: display, title: uuid_str, class: extra[:class]})
    end
  end

  @spec truncate_uuid(String.t(), non_neg_integer(), non_neg_integer()) :: String.t()
  defp truncate_uuid(uuid, prefix_len, 0) do
    String.slice(uuid, 0, prefix_len) <> "..."
  end

  defp truncate_uuid(uuid, prefix_len, suffix_len) do
    prefix = String.slice(uuid, 0, prefix_len)
    suffix = String.slice(uuid, -suffix_len, suffix_len)
    "#{prefix}...#{suffix}"
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
