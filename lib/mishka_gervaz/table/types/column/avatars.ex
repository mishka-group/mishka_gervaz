defmodule MishkaGervaz.Table.Types.Column.Avatars do
  @moduledoc """
  Renders a list of people (a `has_many`/`many_to_many` relationship) as an overlapping avatar stack.

  The people counterpart to `MishkaGervaz.Table.Types.Column.Tags`, and it behaves the same way: up
  to `:max_items` faces show inline (default `3`); any extra collapse behind a `+N` disc that expands
  the rest in place and toggles back on a second click or a click outside. The stack markup lives in
  the UI adapter (`MishkaGervaz.UIAdapters.Tailwind.cell_avatars/1`), so it is themeable and
  overridable per adapter — this type only prepares the data and delegates.

  Each entry is read off the related record by field name, so a resource points at whatever its own
  schema calls those fields rather than renaming them to suit this type. A missing image falls back
  to the first letter of the label on a tinted disc; `:tints` is cycled by position so two
  neighbouring initials never come out the same colour, in the same spirit as `Badge`'s `:colors`.

  The related list is read straight from the record's source field, so it is unaffected by the
  table's display-string join of array values (`get_cell_value/2`), which is why the incoming `value`
  is ignored here.

  Every element id is namespaced by both the column source field and the record id
  (`gz-avatars-<field>-<record_id>`), so several stacks in the same row/table toggle independently.

  ## Options (via `column.ui.extra`)

    * `:max_items`   — faces shown before collapsing into `+N` (default `3`)
    * `:image_field` — field holding the image URL (default `:avatar_url`)
    * `:label_field` — field holding the display name, used for the title and initial (default `:name`)
    * `:tints`       — disc classes cycled by position for entries with no image
    * `:size`        — disc size class (default `"size-[26px]"`)
    * `:empty`       — text shown for an empty/nil list (default `"—"`)

  ## Usage

      column :members do
        ui do
          type :avatars
        end
      end

      column :members do
        ui do
          type :avatars

          extra %{
            max_items: 3,
            label_field: :display_name,
            tints: ["bg-[#eef1fc] text-[#4f4bcc]", "bg-[#eaf7ef] text-[#177a53]"]
          }
        end
      end

  See `MishkaGervaz.Table.Behaviours.ColumnType`, `MishkaGervaz.Table.Types.Column` (the registry)
  and `MishkaGervaz.UIAdapters.Tailwind` (`cell_avatars/1`).
  """
  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  import MishkaGervaz.Helpers, only: [translate_text: 1]

  @default_max_items 3
  @default_tints ["bg-[#f4f3ef] text-[#6d6a63]"]

  @impl true
  def render(_value, column, record, ui) do
    extra = get_extra(column)

    people =
      record
      |> Map.get(source_field(column))
      |> List.wrap()
      |> Enum.reject(&is_nil/1)

    {shown, rest} = Enum.split(people, extra[:max_items] || @default_max_items)

    ui.cell_avatars(%{
      __changed__: %{},
      id: dom_id(column, record),
      shown: entries(shown, 0, extra),
      rest: entries(rest, length(shown), extra),
      more: length(rest),
      size: extra[:size],
      empty: translate_text(extra[:empty])
    })
  end

  @spec entries([map()], non_neg_integer(), map()) :: [map()]
  defp entries(people, offset, extra) do
    tints = List.wrap(extra[:tints] || @default_tints)

    people
    |> Enum.with_index(offset)
    |> Enum.map(fn {person, index} ->
      label = person |> Map.get(extra[:label_field] || :name) |> to_string()

      %{
        image: Map.get(person, extra[:image_field] || :avatar_url),
        initial: label |> String.first() |> to_string() |> String.upcase(),
        label: label,
        tint: Enum.at(tints, rem(index, length(tints)))
      }
    end)
  end

  @spec dom_id(map(), map()) :: String.t()
  defp dom_id(column, record) do
    field = source_field(column)
    base = Map.get(record, :id) || :erlang.phash2({field, Map.get(record, field)})

    ["gz-avatars", Map.get(column, :__table_id__), field, base]
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
