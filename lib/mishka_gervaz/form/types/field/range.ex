defmodule MishkaGervaz.Form.Types.Field.Range do
  @moduledoc """
  Range slider field type. Validates numeric input.

  ## Example

      field :weight, :range do
        min 0
        max 100
        ui do step 5 end
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use MishkaGervaz.Messages

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config) when is_number(value), do: {:ok, value}

  def validate(value, _config) when is_binary(value) and value != "" do
    case Float.parse(value) do
      {_, _} -> {:ok, value}
      :error -> {:error, dgettext_noop("errors", "must be a number")}
    end
  end

  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :range}
end
