defmodule MishkaGervaz.Form.Types.Field.KeyMap do
  @moduledoc """
  Map field type whose keys are declared, drawn as one control per key.

  Use it for a constrained-map column whose shape is fixed and small — a Phoenix attribute's
  `opts`, a set of feature switches, a pair of coordinates. Use `:json` instead when the keys are
  not known ahead of time.

  Each declared key is rendered through the form's UI adapter in the control its `:type` asks for,
  and the field hands back a plain map with string keys.

  ## Example

  As a field of its own, over a `:map` column:

      field :settings, :key_map do
        options [
          [name: :theme, type: :select, options: ~w(light dark), label: "Theme"],
          [name: :compact, type: :toggle, label: "Compact"]
        ]
      end

  Or as a sub-field of a nested row, which is where a Phoenix attribute's `opts` lives:

      nested_field :opts, :key_map do
        options [
          [name: :required, type: :toggle, label: "Required"],
          [name: :default, type: :text, label: "Default", placeholder: "e.g. medium"],
          [name: :doc, type: :text, label: "What it is for"]
        ]
      end

  ## Declaring keys

  Keys are read from `options`, the same place a `:select` keeps the list it offers. Each key is a
  keyword list or a map:

  | Key            | Required      | Meaning                                                     |
  |----------------|---------------|-------------------------------------------------------------|
  | `:name`        | yes           | the key written into the map                                 |
  | `:type`        | no (`:text`)  | `:text`, `:textarea`, `:toggle`, `:checkbox`, `:number`, `:select`, `:json` |
  | `:label`       | no            | shown above the control; humanized from `:name` otherwise    |
  | `:placeholder` | no            | placeholder text, or the empty option's label on a `:select` |
  | `:options`     | for `:select` | the choices, as `{label, value}` pairs or bare values        |

  ## A key that may hold a map or a list

  `:json` is a text control for a key whose value is usually text but may be a map, a list, a number
  or a boolean — a Phoenix attribute's `default`, which is `"medium"` on one attribute and `%{}` on
  another. A text control cannot draw a map at all, and one drawn as text would be saved back as
  text, so the attribute that wanted `%{}` would get the string `"%{}"`. A `:json` key is shown and
  read as the `:json` field type shows and reads its value (`MishkaGervaz.Form.Types.Field.Json`): a
  map or a list is shown as JSON, and what is typed is read as JSON when it is JSON (`{}`, `[1]`,
  `5`, `true`) and kept as text when it is not (`medium`).

  ## Blank keys are dropped

  A key left blank is omitted from the stored map rather than written as `""`, and a toggle left
  off is omitted rather than written as `false`, so "not set" stays distinct from "set to nothing".

  Values are cast to their declared type before they reach the changeset; see
  `MishkaGervaz.Form.Types.Field.Nested`.

  See `MishkaGervaz.Form.Behaviours.FieldType`, `MishkaGervaz.Form.Types.Field`, and
  `MishkaGervaz.Form.Types.Field.KeyList` for the repeating version.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @typedoc "One declared key, as written in `options`."
  @type key :: keyword() | map()

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def parse_params(value, config) when is_map(value) and not is_struct(value) do
    for key <- keys(config),
        raw = Map.get(value, to_string(key.name), Map.get(value, key.name)),
        not blank?(raw),
        into: %{},
        do: {to_string(key.name), cast(raw, key)}
  end

  def parse_params(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :key_map}

  @doc """
  The declared keys, normalised to maps with `:name`, `:type`, `:label`, `:placeholder` and
  `:options`.

  Reads `:keys` if the config carries one, `:options` otherwise. Keys with no `:name` are dropped.

      iex> MishkaGervaz.Form.Types.Field.KeyMap.keys(%{options: [[name: :doc]]})
      [%{name: :doc, type: :text, label: nil, placeholder: nil, options: []}]
  """
  @spec keys(map() | keyword() | nil) :: [map()]
  def keys(config) do
    config
    |> fetch(:keys)
    |> case do
      nil -> fetch(config, :options)
      declared -> declared
    end
    |> List.wrap()
    |> Enum.map(&normalise/1)
    |> Enum.reject(&is_nil(&1.name))
  end

  defp normalise(key) when is_list(key), do: key |> Map.new() |> normalise()

  defp normalise(%{} = key) do
    %{
      name: key[:name] || key["name"],
      type: key[:type] || key["type"] || :text,
      label: key[:label] || key["label"],
      placeholder: key[:placeholder] || key["placeholder"],
      options: key[:options] || key["options"] || []
    }
  end

  defp normalise(_other), do: %{name: nil, type: :text, label: nil, placeholder: nil, options: []}

  defp fetch(config, key) when is_map(config), do: Map.get(config, key)
  defp fetch(config, key) when is_list(config), do: Keyword.get(config, key)
  defp fetch(_config, _key), do: nil

  # A `:json` key is read as the `:json` field type reads its text (`MishkaGervaz.Form.Types.Field.Json`):
  # JSON becomes the value it spells, and text that is not JSON is kept as it came.
  defp cast(raw, %{type: :json}), do: MishkaGervaz.Form.Types.Field.Json.parse_params(raw, %{})
  defp cast(raw, _key), do: raw

  defp blank?(nil), do: true
  defp blank?(false), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false
end
