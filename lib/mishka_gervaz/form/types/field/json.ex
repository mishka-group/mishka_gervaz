defmodule MishkaGervaz.Form.Types.Field.Json do
  @moduledoc """
  JSON editor field type.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config) do
    assigns
  end

  @impl true
  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config) when is_binary(value) and value != "" do
    case Jason.decode(value) do
      {:ok, parsed} -> parsed
      {:error, _} -> value
    end
  end

  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :json}
end
