defmodule MishkaGervaz.Table.Types.Column.Text do
  @moduledoc """
  Default text column type.

  Renders values as plain text with optional truncation.

  ## Options (via column.ui.extra)

  - `:max_length` - Truncate text after this many characters (default: nil)
  - `:truncate_suffix` - Suffix for truncated text (default: "...")
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)
    max_length = extra[:max_length]
    suffix = extra[:truncate_suffix] || "..."

    text = to_string(value)

    {display_text, truncated} =
      if max_length && String.length(text) > max_length do
        {String.slice(text, 0, max_length) <> suffix, true}
      else
        {text, false}
      end

    ui.cell_text(%{
      __changed__: %{},
      text: display_text,
      title: if(truncated, do: text),
      class: extra[:class]
    })
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
