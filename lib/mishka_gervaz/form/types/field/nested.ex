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

  `parse_params/2` casts each row by its sub-field's declared type before the value reaches the
  changeset:

  | Sub-field type        | Cast                                                        |
  |-----------------------|-------------------------------------------------------------|
  | `:checkbox`, `:toggle`| `"true"` / `"on"` / `"1"` to `true`; `"false"` / `"off"` / `"0"` / `""` to `false` |
  | `:number`             | integer, then float                                          |
  | `:key_map`            | each declared key cast, then blanks dropped                  |
  | `:key_list`           | each row cast and pruned, then empty rows dropped            |

  Anything it cannot make sense of is left exactly as it came, and a value that is already the
  right type passes through untouched.

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

  # Casts a checkbox or toggle sub-field to a boolean. An absent key stays absent.
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

  # Casts a key map sub-field: each declared key is cast, then blanks are dropped.
  defp coerce(value, %{type: :key_map} = sub) when is_map(value) and not is_struct(value) do
    keys = MishkaGervaz.Form.Types.Field.KeyMap.keys(sub)

    value
    |> coerce_row(keys)
    |> MishkaGervaz.Form.Types.Field.KeyMap.parse_params(%{keys: keys})
  end

  # Casts a key list sub-field row by row, dropping rows left empty.
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
