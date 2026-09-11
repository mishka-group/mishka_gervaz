defmodule MishkaGervaz.Form.Types.Field.Nested do
  @moduledoc """
  Nested / embedded form field type, used for `inputs_for` and constrained-map columns.

  ## Example

      field :seo_tags, :nested do
        ui do
          add_label "+ Add SEO tag"
          remove_label "Remove"
        end

        nested_field :tag do
          ui do placeholder "meta, link, script" end
        end

        nested_field :content, :textarea do
          ui do rows 3 end
        end
      end

  ## Sub-field values are cast on the way in

  A browser sends every input as a string. For a top-level field Ash casts it at the changeset,
  because the attribute has a type. A nested field on a constrained-map column does not get that:
  `attrs: {:array, :map}` with `fields: [opts: [type: :map]]` accepts whatever shape it is handed,
  so a `:checkbox` sub-field would store `"true"` and a `:number` sub-field `"3"`.

  So `parse_params/2` casts each row by its sub-field's declared type before the value reaches the
  changeset:

  | Sub-field type        | Cast                                                        |
  |-----------------------|-------------------------------------------------------------|
  | `:checkbox`, `:toggle`| `"true"` / `"on"` / `"1"` to `true`; `"false"` / `"off"` / `"0"` / `""` to `false` |
  | `:number`             | integer, then float                                          |
  | `:key_map`            | each declared key cast, then blanks dropped                  |
  | `:key_list`           | each row cast and pruned, then empty rows dropped            |

  Anything it cannot make sense of is left exactly as it came, and a value that is already the
  right type — a record being re-submitted, a param built in code — passes through untouched.

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @truthy ["true", "on", "1", true]
  @falsy ["false", "off", "0", "", false]

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def parse_params(value, config) do
    case declarations(config) do
      [] -> value
      declared -> coerce_rows(value, declared)
    end
  end

  @impl true
  def default_ui, do: %{type: :nested}

  # The rows arrive either as a list or as the index-keyed map a form posts.
  defp coerce_rows(rows, declared) when is_list(rows),
    do: Enum.map(rows, &coerce_row(&1, declared))

  defp coerce_rows(rows, declared) when is_map(rows) and not is_struct(rows),
    do: Map.new(rows, fn {index, row} -> {index, coerce_row(row, declared)} end)

  defp coerce_rows(rows, _declared), do: rows

  defp coerce_row(row, declared) when is_map(row) and not is_struct(row) do
    Enum.reduce(declared, row, fn sub, acc ->
      key = to_string(sub.name)

      case Map.fetch(acc, key) do
        {:ok, raw} -> Map.put(acc, key, coerce(raw, sub))
        :error -> acc
      end
    end)
  end

  defp coerce_row(row, _declared), do: row

  # An unticked checkbox sends nothing, so `false` only reaches here through the hidden companion
  # input the template pairs with it. An absent key stays absent rather than being invented as
  # `false`: "unticked" and "this form does not draw that field" are different things.
  defp coerce(value, %{type: type}) when type in [:checkbox, :toggle] do
    cond do
      value in @truthy -> true
      value in @falsy -> false
      true -> value
    end
  end

  defp coerce(value, %{type: :number}) when is_binary(value) do
    trimmed = String.trim(value)

    with :error <- integer(trimmed),
         :error <- float(trimmed) do
      value
    else
      {:ok, number} -> number
    end
  end

  # A key map is a row of its own, so its declared keys are cast the same way this row's were, and
  # then pruned — in that order. A toggle left off arrives as the string "false" from its hidden
  # companion, and is only recognisable as "nothing to store" once it is a boolean.
  defp coerce(value, %{type: :key_map} = sub) when is_map(value) and not is_struct(value) do
    keys = MishkaGervaz.Form.Types.Field.KeyMap.keys(sub)

    value
    |> coerce_row(keys)
    |> MishkaGervaz.Form.Types.Field.KeyMap.parse_params(%{keys: keys})
  end

  # A key list is a list of those, cast and pruned row by row. A row with nothing left in it is
  # dropped, so adding a row and then leaving it costs nothing.
  defp coerce(value, %{type: :key_list} = sub) do
    keys = MishkaGervaz.Form.Types.Field.KeyMap.keys(sub)

    value
    |> MishkaGervaz.Form.Types.Field.KeyList.rows()
    |> Enum.map(fn row ->
      row
      |> coerce_row(keys)
      |> MishkaGervaz.Form.Types.Field.KeyMap.parse_params(%{keys: keys})
    end)
    |> Enum.reject(&(map_size(&1) == 0))
  end

  defp coerce(value, _sub), do: value

  defp integer(""), do: :error

  defp integer(text) do
    case Integer.parse(text) do
      {number, ""} -> {:ok, number}
      _not_an_integer -> :error
    end
  end

  defp float(""), do: :error

  defp float(text) do
    case Float.parse(text) do
      {number, ""} -> {:ok, number}
      _not_a_float -> :error
    end
  end

  defp declarations(config) when is_map(config), do: Map.get(config, :nested_fields, []) || []
  defp declarations(_config), do: []
end
