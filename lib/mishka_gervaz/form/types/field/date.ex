defmodule MishkaGervaz.Form.Types.Field.Date do
  @moduledoc """
  Date picker field type.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config) when is_binary(value) and value != "" do
    case Date.from_iso8601(value) do
      {:ok, _} -> {:ok, value}
      {:error, _} -> {:error, "must be a valid date"}
    end
  end

  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: String.trim(value)
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :date}
end
