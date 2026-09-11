defmodule MishkaGervaz.Form.Types.Field.Nested do
  @moduledoc """
  Nested / embedded form field type. Used for `inputs_for` and constrained-map fields.

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

  ## Sub-fields are typed on the way IN, not only on the way out

  A browser sends every input as a string. For a top-level field that is Ash's problem and Ash solves
  it — the attribute has a type and the cast happens at the changeset. A nested field on a
  constrained MAP column has no such luck: `attrs: {:array, :map}` with `fields: [opts: [type: :map]]`
  accepts whatever shape it is handed, so a `:checkbox` sub-field stored `"true"`, a `:number` stored
  `"3"`, and every reader downstream had to know that and cope.

  They did not cope. A component declaring `required` through the form stored the string `"true"`,
  and `Inspector.required?/1` — which asks `== true`, as anything reading a boolean should — saw a
  string and said no. The declaration looked right in the form and did nothing anywhere else.

  So `parse_params/2` coerces each row by the sub-field's DECLARED type before the value reaches the
  changeset: the declaration is already there, it is the only thing that knows what the string was
  meant to be, and doing it once here is the alternative to every reader guessing.

  Anything it cannot make sense of is left exactly as it came. A value that is already the right type
  — a record being re-submitted, a param built in code — passes through untouched.

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

  # A CHECKBOX THAT IS NOT TICKED SENDS NOTHING AT ALL, which is why `false` is reachable here only
  # through the hidden companion input the template pairs with it. An absent key is left absent
  # rather than invented: "unticked" and "this form does not draw that field" are different, and only
  # the first one is this function's business.
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

  # A KEY MAP IS A ROW OF ITS OWN, so its declared keys are coerced the same way this row's were —
  # and THEN pruned, in that order: a toggle left off arrives as the string "false" from its hidden
  # companion, which is only recognisable as "nothing to store" once it is a boolean.
  defp coerce(value, %{type: :key_map} = sub) when is_map(value) and not is_struct(value) do
    keys = MishkaGervaz.Form.Types.Field.KeyMap.keys(sub)

    value
    |> coerce_row(keys)
    |> MishkaGervaz.Form.Types.Field.KeyMap.parse_params(%{keys: keys})
  end

  # AND A KEY LIST IS A LIST OF THOSE, coerced and pruned row by row. A row with nothing left in it
  # is dropped: pressing "add" and thinking better of it should cost nothing.
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
