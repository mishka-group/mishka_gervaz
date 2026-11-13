defmodule MishkaGervaz.Form.Types.Field.Range do
  @moduledoc """
  Range slider field type. Validates numeric input. The slider runs from the field's `min` to its
  `max` (0 to 100 when not set) in `ui` `step`s, and a value outside them gets the field's error.

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

  alias MishkaGervaz.Form.Types.Field.Number

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, config) when is_number(value), do: Number.within(value, value, config)

  def validate(value, config) when is_binary(value) and value != "" do
    case Float.parse(value) do
      {number, _rest} -> Number.within(value, number, config)
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
