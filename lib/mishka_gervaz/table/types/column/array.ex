defmodule MishkaGervaz.Table.Types.Column.Array do
  @moduledoc """
  Array/List column type.

  Renders array values with customizable display.

  ## Options (via column.ui.extra)

  - `:separator` - Separator between items (default: ", ")
  - `:max_items` - Maximum items to show (default: nil, show all)
  - `:as_badges` - Render each item as a badge (default: false)
  - `:badge_class` - CSS class for badges (default: "bg-gray-100 text-gray-800")
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render([], _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) when is_list(value) do
    extra = get_extra(column)
    max_items = extra[:max_items]

    items =
      if max_items && length(value) > max_items do
        Enum.take(value, max_items)
      else
        value
      end

    remaining = length(value) - length(items)

    if extra[:as_badges] do
      render_as_badges(items, remaining, extra, ui)
    else
      render_as_text(items, remaining, extra, ui)
    end
  end

  def render(value, column, record, ui) do
    case value do
      %MapSet{} -> render(MapSet.to_list(value), column, record, ui)
      _ -> render([value], column, record, ui)
    end
  end

  @spec render_as_text(list(), non_neg_integer(), map(), module()) ::
          Phoenix.LiveView.Rendered.t()
  defp render_as_text(items, remaining, extra, ui) do
    separator = extra[:separator] || ", "
    text = Enum.map_join(items, separator, &to_string/1)
    suffix = if remaining > 0, do: " +#{remaining} more", else: nil

    ui.cell_text(%{
      __changed__: %{},
      text: text,
      suffix: suffix,
      class: extra[:class]
    })
  end

  @spec render_as_badges(list(), non_neg_integer(), map(), module()) ::
          Phoenix.LiveView.Rendered.t()
  defp render_as_badges(items, remaining, extra, ui) do
    badges =
      Enum.map(items, fn item ->
        ui.badge(%{__changed__: %{}, label: to_string(item), class: extra[:badge_class]})
      end)

    remaining_el =
      if remaining > 0 do
        ui.cell_text(%{__changed__: %{}, text: "+#{remaining}", class: extra[:remaining_class]})
      end

    assigns = %{badges: badges, remaining_el: remaining_el, class: extra[:class], ui: ui}

    ~H"""
    {@ui.cell_array(%{__changed__: %{}, class: @class, badges: @badges, remaining: @remaining_el})}
    """
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
