defmodule MishkaGervaz.Form.Types.Field.StringList do
  @moduledoc """
  String list field type.

  Renders as a dynamic list of text inputs with add / remove buttons.
  Used for `{:array, :string}` attributes such as allowed origins, tags,
  and so on. Sanitize trims each item and keeps it as typed; an item that holds an HTML tag is
  refused as a `:text` field's value is (`MishkaGervaz.Form.Types.Field.Text.plain_text/1`). Empty
  strings are filtered out on `parse_params/2`.

  ## Example

      field :keywords, :string_list do
        ui do
          add_label "+ Add keyword"
          remove_label "Remove"
        end
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  alias MishkaGervaz.Form.Types.Field.Text

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config) when is_list(value) do
    case Enum.find(value, &match?({:error, _}, Text.plain_text(&1))) do
      nil -> {:ok, value}
      item -> Text.plain_text(item)
    end
  end

  def validate(value, _config) when is_binary(value) and value != "", do: {:ok, [value]}
  def validate(nil, _config), do: {:ok, []}
  def validate(_, _config), do: {:ok, []}

  @impl true
  def parse_params(value, _config) when is_list(value), do: Enum.reject(value, &(&1 == ""))
  def parse_params(value, _config) when is_binary(value) and value != "", do: [value]
  def parse_params(_, _config), do: []

  @impl true
  def sanitize(value, _config) when is_list(value) do
    Enum.map(value, fn
      item when is_binary(item) -> String.trim(item)
      item -> item
    end)
  end

  def sanitize(value, _config) when is_binary(value), do: String.trim(value)

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :string_list}
end
