defmodule MishkaGervaz.Form.Types.Field.KeyList do
  @moduledoc """
  List field type whose rows have declared keys — `MishkaGervaz.Form.Types.Field.KeyMap` repeated,
  with rows the author can add and remove.

  Use it for a `{:array, :map}` column whose entries have a fixed, small shape: a Phoenix slot's
  `attrs`, a list of redirects, a set of social links. Use `:json` instead when the entries are not
  known ahead of time.

  ## Example

  As a field of its own, over an `{:array, :map}` column:

      field :social_links, :key_list do
        options [
          [name: :platform, type: :text, placeholder: "e.g. github"],
          [name: :url, type: :text, placeholder: "https://…"]
        ]

        ui do
          label "Social links"
          add_label "+ Add link"
        end
      end

  Or as a sub-field of a nested row, which is where a Phoenix slot's `attrs` lives:

      nested_field :attrs, :key_list do
        options [
          [name: :name, type: :text, placeholder: "e.g. label"],
          [name: :type, type: :select, options: ~w(string integer boolean any)],
          [name: :required, type: :toggle, label: "Required"]
        ]

        ui do
          label "Slot Attributes"
          add_label "+ Add Attribute"
          remove_label "Remove"
        end
      end

  Keys are declared exactly as `:key_map` declares them, a list or `fn state -> keys end` — see its
  docs for the options each key takes. `add_label` and `remove_label` name the two buttons; they
  default to `+ Add` and `Remove`.

  ## Row labels

  Each row's head reads its number, from 1. A field of its own may name its rows by what they hold
  with `row_label`: a key's name, whose value the head reads, or a function of the row:

      field :amounts, :key_list do
        options [
          [name: :currency, type: :select, options: ~w(USD EUR GBP)],
          [name: :amount, type: :number]
        ]

        row_label :currency
      end

  `row_label fn row, index -> "\#{row["currency"]} (\#{index + 1})" end` builds the label itself.
  A row whose label comes out `nil` or blank, a new row say, still reads its number. See
  `row_label/3`.

  ## Where it works

  Both positions carry the same controls; only the events behind the two buttons differ, because
  the two lists sit at different depths in the params:

  | Position                        | Column               | Rows added and removed by       |
  |---------------------------------|----------------------|----------------------------------|
  | a field of its own              | `{:array, :map}`     | `add_nested` / `remove_nested`   |
  | a sub-field of a `:nested` field | a constrained map    | `add_key_row` / `remove_key_row` |

  A sub-field only gets the buttons on the constrained-map path, where a row has an index to
  address. On an embedded nested field its rows still render, read-only.

  ## Empty rows are dropped

  A row whose declared keys are all blank is omitted rather than stored as a map of empty strings,
  so adding a row and then leaving it costs nothing. Values are cast to their declared type before
  they reach the changeset; see `MishkaGervaz.Form.Types.Field.Nested`.

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  alias MishkaGervaz.Form.Types.Field.KeyMap

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def parse_params(value, config) do
    keys = keys(config)

    value
    |> rows()
    |> Enum.map(&KeyMap.parse_params(&1, %{keys: keys}))
    |> Enum.reject(&(map_size(&1) == 0))
  end

  @impl true
  def default_ui, do: %{type: :key_list}

  @doc """
  The declared keys of one row. Delegates to `MishkaGervaz.Form.Types.Field.KeyMap.keys/1`.
  """
  @spec keys(map() | keyword() | nil) :: [map()]
  defdelegate keys(config), to: KeyMap

  @doc """
  The declared keys of one row, with `options fn state -> keys end` read with the form `state`.
  Delegates to `MishkaGervaz.Form.Types.Field.KeyMap.keys/2`.
  """
  @spec keys(map() | keyword() | nil, map()) :: [map()]
  defdelegate keys(config, state), to: KeyMap

  @doc """
  The rows in order, whether they arrived as a list or as the index-keyed map a form posts.

  A form sends `attrs[0][name]`, `attrs[1][name]` and so on, which Phoenix hands back as
  `%{"0" => …, "1" => …}`; the indices give the order. A value read back off the column is already
  a list and is returned as it stands. Anything that is not a map — including the hidden marker the
  template posts so an empty list can be expressed at all — is dropped.

      iex> MishkaGervaz.Form.Types.Field.KeyList.rows(%{"1" => %{"a" => 1}, "0" => %{"a" => 0}})
      [%{"a" => 0}, %{"a" => 1}]
  """
  @spec rows(term()) :: [map()]
  def rows(value) when is_list(value), do: Enum.filter(value, &plain_map?/1)

  def rows(value) when is_map(value) and not is_struct(value) do
    value
    |> Enum.sort_by(fn {index, _row} ->
      case index |> to_string() |> Integer.parse() do
        {number, ""} -> number
        _not_a_number -> 0
      end
    end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.filter(&plain_map?/1)
  end

  def rows(_value), do: []

  @doc """
  What the head of row `index` (from 0) reads: the value of the key `row_label` names, or what
  `fn row -> label end` or `fn row, index -> label end` returns, given the row with string keys.

  The row's number, `index + 1`, is the label when `row_label` is `nil`, and when the label comes
  out `nil` or blank. An atom or a number is drawn as its text.

      iex> MishkaGervaz.Form.Types.Field.KeyList.row_label(:currency, %{currency: "USD"}, 0)
      "USD"

      iex> MishkaGervaz.Form.Types.Field.KeyList.row_label(:currency, %{"currency" => ""}, 1)
      "2"

      iex> MishkaGervaz.Form.Types.Field.KeyList.row_label(&String.upcase(&1["code"]), %{code: "eur"}, 0)
      "EUR"
  """
  @spec row_label(
          atom() | (map() -> term()) | (map(), non_neg_integer() -> term()) | nil,
          map(),
          non_neg_integer()
        ) :: String.t()
  def row_label(row_label, row, index) do
    row_label
    |> label_of(row, index)
    |> label_text(index)
  end

  defp label_of(nil, _row, _index), do: nil

  defp label_of(key, row, _index) when is_atom(key),
    do: Map.get(row, to_string(key), Map.get(row, key))

  defp label_of(fun, row, _index) when is_function(fun, 1), do: fun.(string_keys(row))
  defp label_of(fun, row, index) when is_function(fun, 2), do: fun.(string_keys(row), index)

  defp label_text(label, index) when is_binary(label) do
    case String.trim(label) do
      "" -> Integer.to_string(index + 1)
      _text -> label
    end
  end

  defp label_text(label, _index) when is_number(label), do: to_string(label)

  defp label_text(label, _index) when is_atom(label) and label not in [nil, true, false],
    do: Atom.to_string(label)

  defp label_text(_label, index), do: Integer.to_string(index + 1)

  defp string_keys(row), do: Map.new(row, fn {key, value} -> {to_string(key), value} end)

  defp plain_map?(row), do: is_map(row) and not is_struct(row)
end
