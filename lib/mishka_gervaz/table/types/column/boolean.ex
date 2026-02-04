defmodule MishkaGervaz.Table.Types.Column.Boolean do
  @moduledoc """
  Boolean column type with icon display.

  Renders true/false values as checkmark/X icons.

  ## Options (via column.ui.extra)

  - `:true_icon` - Icon for true value (default: "hero-check")
  - `:false_icon` - Icon for false value (default: "hero-x-mark")
  - `:true_class` - CSS class for true (default: "text-green-600")
  - `:false_class` - CSS class for false (default: "text-red-600")
  - `:true_label` - Text label for true (alternative to icon)
  - `:false_label` - Text label for false (alternative to icon)
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)

    if value do
      render_true(extra, ui)
    else
      render_false(extra, ui)
    end
  end

  @spec render_true(map(), module()) :: Phoenix.LiveView.Rendered.t()
  defp render_true(extra, ui) do
    label = extra[:true_label]

    if label do
      ui.cell_text(%{__changed__: %{}, text: label, class: extra[:true_class]})
    else
      %{__changed__: %{}, variant: :boolean_true}
      |> maybe_put(:name, extra[:true_icon])
      |> maybe_put(:class, extra[:true_class])
      |> ui.icon()
    end
  end

  @spec render_false(map(), module()) :: Phoenix.LiveView.Rendered.t()
  defp render_false(extra, ui) do
    label = extra[:false_label]

    if label do
      ui.cell_text(%{__changed__: %{}, text: label, class: extra[:false_class]})
    else
      %{__changed__: %{}, variant: :boolean_false}
      |> maybe_put(:name, extra[:false_icon])
      |> maybe_put(:class, extra[:false_class])
      |> ui.icon()
    end
  end

  @spec maybe_put(map(), atom(), term()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
