defmodule MishkaGervaz.Form.Types.Field.Number do
  @moduledoc """
  Numeric input field type.

  Validates against the field's `ash_type`: `:integer` / `Ash.Type.Integer`
  reject decimals; other numeric Ash types accept either integers or floats.
  Sanitizes string input by stripping HTML and trimming whitespace.

  ## Example

      field :priority, :number do
        min 0
        max 10
        ui do step 1 end
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use MishkaGervaz.Messages

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, config) when is_number(value) do
    if integer_type?(Map.get(config || %{}, :ash_type)) and not is_integer(value) do
      {:error, dgettext_noop("errors", "must be a whole number")}
    else
      {:ok, value}
    end
  end

  def validate(value, config) when is_binary(value) and value != "" do
    case Integer.parse(value) do
      {_, ""} ->
        {:ok, value}

      _ ->
        if integer_type?(Map.get(config || %{}, :ash_type)) do
          {:error, dgettext_noop("errors", "must be a whole number")}
        else
          case Float.parse(value) do
            {_, _} -> {:ok, value}
            :error -> {:error, dgettext_noop("errors", "must be a number")}
          end
        end
    end
  end

  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value) do
    value |> MishkaGervaz.Helpers.strip_tags() |> String.trim()
  end

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :number}

  defp integer_type?(:integer), do: true
  defp integer_type?(Ash.Type.Integer), do: true
  defp integer_type?(_), do: false
end
