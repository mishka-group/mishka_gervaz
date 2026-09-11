defmodule MishkaGervaz.Form.Types.Field.KeyList do
  @moduledoc """
  A LIST of maps whose keys are known — `MishkaGervaz.Form.Types.Field.KeyMap` repeated, with rows
  an author can add and remove.

  ## What it is for

  `:key_map` answers "this map has these three keys". A great many constrained-map columns hold the
  next thing along: a LIST of such maps. A Phoenix slot's `attrs` is the example this was written
  for — each entry is `name` / `type` / `required` and nothing else, and there may be none, one, or
  six of them.

  Given a JSON textarea for that, an author has to write `[{"name": "label", "type": "string"}]` by
  hand, brackets and quotes and commas included, to declare one attribute on one slot. This draws a
  row of real controls per entry, with a button to add another and a button to take one away.

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

  The keys are declared exactly as `:key_map` declares them — `options` is one place on the
  declaration for "what this field may contain", whatever the field is.

  ## An empty row is not a row

  A row whose every declared key is blank is DROPPED rather than stored as a map of empty strings,
  for the reason `KeyMap` drops a blank key: a constrained map is read by asking whether something
  is there. So pressing "add" and then thinking better of it costs nothing, and neither does a row
  left half-typed and abandoned — it simply never reaches the column.

  See `MishkaGervaz.Form.Types.Field.KeyMap` and `MishkaGervaz.Form.Types.Field.Nested`, which
  coerces a key list's rows by their declared types the same way it coerces the row around them.
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
  The declared keys of one row, read the same way `KeyMap` reads them.
  """
  @spec keys(map() | keyword() | nil) :: [map()]
  defdelegate keys(config), to: KeyMap

  @doc """
  The rows, in order, whether they arrived as a list or as the index-keyed map a form posts.

  A form sends `attrs[0][name]`, `attrs[1][name]` and so on, which Phoenix hands back as
  `%{"0" => …, "1" => …}` — and a map has no order, so the indices are what the order is. A record
  read back off the column is already a list and is taken as it stands.
  """
  @spec rows(term()) :: [map()]
  def rows(value) when is_list(value), do: Enum.filter(value, &plain_map?/1)

  def rows(value) when is_map(value) and not is_struct(value) do
    value
    |> Enum.sort_by(fn {index, _row} -> position(index) end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.filter(&plain_map?/1)
  end

  def rows(_value), do: []

  defp plain_map?(row), do: is_map(row) and not is_struct(row)

  defp position(index) do
    case index |> to_string() |> Integer.parse() do
      {number, ""} -> number
      _not_a_number -> 0
    end
  end
end
