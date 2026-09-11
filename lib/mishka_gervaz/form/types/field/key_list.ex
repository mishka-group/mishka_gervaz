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

  Keys are declared exactly as `:key_map` declares them — see its docs for the options each key
  takes. `add_label` and `remove_label` name the two buttons; they default to `+ Add` and `Remove`.

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

  defp plain_map?(row), do: is_map(row) and not is_struct(row)
end
