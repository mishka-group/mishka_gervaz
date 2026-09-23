defmodule MishkaGervaz.Table.Types.Column.Tags do
  @moduledoc """
  Renders a list value (e.g. `{:array, :string}`) as individual tag/badge chips.

  Up to `:max_items` chips show inline (default `2`); any extra collapse behind a `+N` chip that
  expands the rest in place and toggles back on a second click or a click outside. The chip/toggle
  markup lives in the UI adapter (`MishkaGervaz.UIAdapters.Tailwind.cell_tags/1`), so it is themeable
  and overridable per adapter — this type only prepares the data and delegates, exactly like
  `MishkaGervaz.Table.Types.Column.Badge` delegates to `ui.badge/1`.

  The raw list is read straight from the record's source field, so it is unaffected by the table's
  display-string join of array values (`get_cell_value/2`) — that join would otherwise hand this type
  one space-joined string instead of a list, which is why the incoming `value` is ignored here.

  Every element id is namespaced by both the column source field and the record id
  (`gz-tags-<field>-<record_id>`), so several `:tags` columns in the same row/table each toggle
  independently.

  An item is a string, or `%{label: …, class: …, title: …}` for a chip styled on its own — see
  `MishkaGervaz.UIAdapters.Tailwind.cell_tags/1`.

  ## Options (via `column.ui.extra`)

    * `:max_items`   — chips shown before collapsing into `+N` (default `2`)
    * `:badge_class` — chip CSS class (defaults to the adapter's neutral pill)
    * `:empty`       — text shown for an empty/nil list (default `"—"`)

  ## Usage

      column :dependencies do
        ui do
          type :tags
        end
      end

      column :dependencies do
        ui do
          type :tags
          extra %{max_items: 3, badge_class: "rounded-full bg-[#f2f1fc] px-2 py-0.5 text-[#4f4bcc]"}
        end
      end

  See `MishkaGervaz.Table.Behaviours.ColumnType`, `MishkaGervaz.Table.Types.Column` (the registry) and
  `MishkaGervaz.UIAdapters.Tailwind` (`cell_tags/1`).
  """
  @behaviour MishkaGervaz.Table.Behaviours.ColumnType

  @impl true
  def render(_value, column, record, ui) do
    extra = get_extra(column)

    items =
      record
      |> Map.get(source_field(column))
      |> List.wrap()
      |> Enum.reject(&(&1 in [nil, ""]))

    max_items = extra[:max_items] || 2

    ui.cell_tags(%{
      __changed__: %{},
      id: dom_id(column, record),
      shown: Enum.take(items, max_items),
      rest: Enum.drop(items, max_items),
      more: max(0, length(items) - max_items),
      badge_class: extra[:badge_class],
      empty: extra[:empty]
    })
  end

  @spec dom_id(map(), map()) :: String.t()
  defp dom_id(column, record) do
    field = source_field(column)
    base = Map.get(record, :id) || :erlang.phash2({field, Map.get(record, field)})

    ["gz-tags", Map.get(column, :__table_id__), field, base]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("-")
  end

  @spec source_field(map()) :: atom()
  defp source_field(%{source: source}) when is_atom(source) and not is_nil(source), do: source
  defp source_field(%{name: name}), do: name

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
