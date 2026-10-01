defmodule MishkaGervaz.Table.Types.Column.Badge do
  @moduledoc """
  Badge/status column type — maps a cell value to a coloured badge via config, so a resource declares
  the colour/label mapping instead of hand-rolling badge markup in a `render` function.

  ## Options (via `column.ui.extra`)

    * `:colors`  - map of value → colour class, e.g. `%{"active" => "bg-[#e6f6ee] text-[#177a53]"}`
    * `:labels`  - map of value → display label, translated in the caller's locale (falls back to a humanized value)
    * `:dots`    - map of value → dot colour class for the `:pill` variant, e.g. `%{"active" => "bg-[#1f9d6b]"}`
    * `:variant` - `:tag` (default, square-ish, no dot) or `:pill` (rounded with a leading dot)
    * `:default_color` - colour class when the value is not in `:colors`

  Keys are matched by the value's string form first, then its existing-atom form, so either
  `%{"hybrid" => ...}` or `%{hybrid: ...}` works. Example:

      column :mode do
        ui do
          type :badge
          extra %{
            colors: %{"hybrid" => "bg-[#f1edfb] text-[#7a5bd0]"},
            labels: %{"hybrid" => "Hybrid"},
            default_color: "bg-[#f2f1ec] text-[#8a877f]"
          }
        end
      end

  See `MishkaGervaz.Table.Types.Column` (registry), `MishkaGervaz.Table.Behaviours.ColumnType`, and
  `MishkaGervaz.UIAdapters.Tailwind` (`badge/1`).
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component
  import MishkaGervaz.Helpers, only: [humanize: 1, translate_text: 1]

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)
    key = to_string(value)

    ui.badge(%{
      __changed__: %{},
      label: translate_text(lookup(extra[:labels], key, humanize(value))),
      class: lookup(extra[:colors], key, extra[:default_color]),
      dot: lookup(extra[:dots], key, nil),
      variant: extra[:variant] || :tag
    })
  end

  @spec lookup(map() | nil, String.t(), term()) :: term()
  defp lookup(map, key, default) when is_map(map) do
    with :error <- Map.fetch(map, key),
         atom_key when not is_nil(atom_key) <- existing_atom(key),
         {:ok, value} <- Map.fetch(map, atom_key) do
      value
    else
      {:ok, value} -> value
      _ -> default
    end
  end

  defp lookup(_map, _key, default), do: default

  @spec existing_atom(String.t()) :: atom() | nil
  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
