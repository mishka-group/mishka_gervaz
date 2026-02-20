defmodule MishkaGervaz.Form.Types.Field.DateTime do
  @moduledoc """
  DateTime picker field type.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config) do
    assigns
  end

  @impl true
  def validate(value, _config) when is_binary(value) and value != "" do
    cond do
      match?({:ok, _}, NaiveDateTime.from_iso8601(value)) -> {:ok, value}
      match?({:ok, _, _}, DateTime.from_iso8601(value)) -> {:ok, value}
      true -> {:error, "must be a valid date and time"}
    end
  end

  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: String.trim(value)
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :datetime}
end
