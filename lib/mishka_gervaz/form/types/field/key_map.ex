defmodule MishkaGervaz.Form.Types.Field.KeyMap do
  @moduledoc """
  A MAP whose keys are known, drawn as real controls instead of a JSON box.

  ## What it is for

  `:json` is the right field for a map whose shape nobody can predict — a settings blob, an imported
  payload, a schema fragment. It is the wrong one for a map whose keys are *declared and few*, and a
  great many constrained-map columns are exactly that: a Phoenix attribute's `opts` is
  `required` / `default` / `doc` and nothing else, forever.

  Given a JSON textarea for those three, an author has to know the key names, know they are strings,
  know the quoting, and get the braces right — to tick one box. This draws the keys the declaration
  names, in the controls their types ask for, and hands back a map.

      nested_field :opts, :key_map do
        options [
          [name: :required, type: :toggle, label: "Required"],
          [name: :default, type: :text, label: "Default", placeholder: "e.g. medium"],
          [name: :doc, type: :text, label: "What it is for"]
        ]
      end

  Each key takes `:name` and optionally `:type` (`:text`, `:textarea`, `:toggle`, `:checkbox`,
  `:number`, `:select`), `:label`, `:placeholder` and, for a select, `:options`.

  ## Empty means absent

  A key left blank is DROPPED rather than written as `""`, and a toggle left off is dropped rather
  than written as `false`. A constrained map is read by asking whether a key is there — Phoenix's own
  `attr` treats `default: nil` and no default as different things — so writing every declared key on
  every save would turn "not set" into "set to nothing" for every reader downstream.

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field.Nested`, which
  coerces a key map's values the same way it coerces the row around it.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @typedoc "One declared key, as written in `options`."
  @type key :: keyword() | map()

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def parse_params(value, config) when is_map(value) and not is_struct(value) do
    value
    |> Map.take(Enum.map(keys(config), &to_string(name_of(&1))))
    |> Enum.reject(fn {_key, raw} -> blank?(raw) end)
    |> Map.new()
  end

  def parse_params(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :key_map}

  @doc """
  The declared keys, normalised to maps carrying at least `:name` and `:type`.

  Read off the sub-field's `options`, which is where a `:select` sub-field already keeps the list it
  offers — one place on the declaration for "what this field may contain", whatever the field is.
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

  defp name_of(%{name: name}), do: name

  defp fetch(config, key) when is_map(config), do: Map.get(config, key)
  defp fetch(config, key) when is_list(config), do: Keyword.get(config, key)
  defp fetch(_config, _key), do: nil

  defp blank?(nil), do: true
  defp blank?(false), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false
end
