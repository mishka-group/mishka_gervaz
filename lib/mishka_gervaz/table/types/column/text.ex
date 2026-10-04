defmodule MishkaGervaz.Table.Types.Column.Text do
  @moduledoc """
  Default text column type.

  Renders values as plain text with optional truncation.

  ## Options (via column.ui.extra)

  - `:max_length` - Truncate text after this many characters (default: nil)
  - `:truncate_suffix` - Suffix for truncated text (default: "...")
  - `:dir` - `"ltr"`, `"rtl"` or `"auto"` (default: a value of printable ASCII with no space, such
    as an email, URL or ID, reads left to right and any other value follows the page)

  ## Example

      column :excerpt do
        ui do
          type :text
          extra %{max_length: 80, truncate_suffix: "…"}
        end
      end

  See `MishkaGervaz.Table.Types.Column` (registry),
  `MishkaGervaz.Table.Behaviours.ColumnType`, and
  `MishkaGervaz.Table.Entities.Column`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)
    max_length = extra[:max_length]
    suffix = extra[:truncate_suffix] || "..."

    text = stringify(value)

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
      class: extra[:class],
      dir: extra[:dir]
    })
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}

  defp stringify(value) when is_binary(value), do: value

  defp stringify(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: inspect(value)
  end
end
