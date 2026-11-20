defmodule MishkaGervaz.Form.Types.Field.Number do
  @moduledoc """
  Numeric input field type.

  Validates against the field's `ash_type`: `:integer` / `Ash.Type.Integer`
  reject decimals; other numeric Ash types accept either integers or floats.
  Sanitizes string input by stripping HTML and trimming whitespace. A value below the field's `min`
  or above its `max` gets the field's error, and the input carries both, with `ui` `step`. A bound
  may be an integer, a float or a `Decimal`; a value is compared with it as a `Decimal`, so
  `0.1` and `Decimal.new("0.10")` are equal.

  ## Example

      field :priority, :number do
        min 0
        max 10
        ui do step 1 end
      end

      field :price, :number do
        min Decimal.new("0.50")
        max Decimal.new("9999.99")
        ui do step 0.01 end
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
      within(value, value, config)
    end
  end

  def validate(%Decimal{} = value, config), do: within(value, value, config)

  def validate(value, config) when is_binary(value) and value != "" do
    case Integer.parse(value) do
      {number, ""} ->
        within(value, number, config)

      _ ->
        if integer_type?(Map.get(config || %{}, :ash_type)) do
          {:error, dgettext_noop("errors", "must be a whole number")}
        else
          case Float.parse(value) do
            {_number, _rest} -> within(value, decimal_or_float(value), config)
            :error -> {:error, dgettext_noop("errors", "must be a number")}
          end
        end
    end
  end

  def validate(value, _config), do: {:ok, value}

  @doc """
  `{:ok, value}` when `number`, the number `value` holds, is within the `min` and `max` of the
  field `config`; otherwise the field's error. `number` and the bounds may each be an integer, a
  float or a `Decimal`, compared as `Decimal`s. A bound given as a function of no arguments is
  called; one that is not a number is not checked.
  """
  @spec within(term(), number() | Decimal.t(), map() | nil) ::
          {:ok, term()} | {:error, String.t()}
  def within(value, number, config) do
    config = config || %{}

    cond do
      below?(number, Map.get(config, :min)) -> {:error, dgettext_noop("errors", "is too small")}
      below?(Map.get(config, :max), number) -> {:error, dgettext_noop("errors", "is too large")}
      true -> {:ok, value}
    end
  end

  defp below?(bound, other) when is_function(bound, 0), do: below?(bound.(), other)
  defp below?(number, bound) when is_function(bound, 0), do: below?(number, bound.())

  defp below?(number, other) do
    case {decimal(number), decimal(other)} do
      {%Decimal{} = number, %Decimal{} = other} -> Decimal.lt?(number, other)
      _not_both_numbers -> false
    end
  end

  defp decimal(%Decimal{} = number), do: number
  defp decimal(number) when is_integer(number), do: Decimal.new(number)
  defp decimal(number) when is_float(number), do: Decimal.from_float(number)
  defp decimal(_other), do: nil

  # A typed value read as written, `"0.10"` as `0.10`, so it meets a `Decimal` bound exactly.
  defp decimal_or_float(value) do
    case Decimal.parse(value) do
      {number, ""} -> number
      _other -> value |> Float.parse() |> elem(0)
    end
  end

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
