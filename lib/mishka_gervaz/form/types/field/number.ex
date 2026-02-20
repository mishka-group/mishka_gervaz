defmodule MishkaGervaz.Form.Types.Field.Number do
  @moduledoc """
  Numeric input field type.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config) do
    assigns
  end

  @impl true
  def validate(value, config) when is_number(value) do
    if integer_type?(Map.get(config || %{}, :ash_type)) and not is_integer(value) do
      {:error, "must be a whole number"}
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
          {:error, "must be a whole number"}
        else
          case Float.parse(value) do
            {_, _} -> {:ok, value}
            :error -> {:error, "must be a number"}
          end
        end
    end
  end

  def validate(value, _config), do: {:ok, value}

  defp integer_type?(:integer), do: true
  defp integer_type?(Ash.Type.Integer), do: true
  defp integer_type?(_), do: false

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value) do
    value |> String.replace(~r/<[^>]*>/, "") |> String.trim()
  end

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :number}
end
