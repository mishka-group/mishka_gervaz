defmodule MishkaGervaz.Form.Types.Field.StringList do
  @moduledoc """
  String list field type.

  Renders as a dynamic list of text inputs with add/remove buttons.
  Used for `{:array, :string}` attributes like allowed origins, tags, etc.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config) when is_list(value), do: {:ok, value}
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
      item when is_binary(item) -> item |> String.replace(~r/<[^>]*>/, "") |> String.trim()
      item -> item
    end)
  end

  def sanitize(value, _config) when is_binary(value) do
    value |> String.replace(~r/<[^>]*>/, "") |> String.trim()
  end

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :string_list}
end
