defmodule MishkaGervaz.Table.Types.Column.Number do
  @moduledoc """
  Numeric column type.

  Renders numeric values with optional formatting.

  ## Options (via column.ui.extra)

  - `:precision` - Decimal precision (default: nil, shows as-is)
  - `:prefix` - Prefix string (e.g., "$")
  - `:suffix` - Suffix string (e.g., "%", " kg")
  - `:thousands_separator` - Separator for thousands (default: ",")
  - `:decimal_separator` - Decimal separator (default: ".")
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, _record, ui) do
    extra = get_extra(column)
    formatted = format_number(value, extra)

    ui.cell_number(%{
      __changed__: %{},
      value: formatted,
      prefix: extra[:prefix],
      suffix: extra[:suffix],
      class: extra[:class]
    })
  end

  @spec format_number(term(), map()) :: String.t()
  defp format_number(value, extra) when is_integer(value) do
    thousands_sep = extra[:thousands_separator] || ","

    value
    |> Integer.to_string()
    |> add_thousands_separator(thousands_sep)
  end

  defp format_number(value, extra) when is_float(value) do
    precision = extra[:precision]
    thousands_sep = extra[:thousands_separator] || ","
    decimal_sep = extra[:decimal_separator] || "."

    formatted =
      if precision do
        :erlang.float_to_binary(value, decimals: precision)
      else
        Float.to_string(value)
      end

    case String.split(formatted, ".") do
      [integer_part, decimal_part] ->
        integer_formatted = add_thousands_separator(integer_part, thousands_sep)
        "#{integer_formatted}#{decimal_sep}#{decimal_part}"

      [integer_part] ->
        add_thousands_separator(integer_part, thousands_sep)
    end
  end

  defp format_number(%Decimal{} = value, extra) do
    precision = extra[:precision]

    formatted =
      if precision do
        Decimal.round(value, precision)
      else
        value
      end
      |> Decimal.to_string()

    format_number_string(formatted, extra)
  end

  defp format_number(value, extra) do
    format_number_string(to_string(value), extra)
  end

  @spec format_number_string(String.t(), map()) :: String.t()
  defp format_number_string(str, extra) do
    thousands_sep = extra[:thousands_separator] || ","
    decimal_sep = extra[:decimal_separator] || "."

    case String.split(str, ".") do
      [integer_part, decimal_part] ->
        integer_formatted = add_thousands_separator(integer_part, thousands_sep)
        "#{integer_formatted}#{decimal_sep}#{decimal_part}"

      [integer_part] ->
        add_thousands_separator(integer_part, thousands_sep)
    end
  end

  @spec add_thousands_separator(String.t(), String.t()) :: String.t()
  defp add_thousands_separator(integer_str, separator) do
    integer_str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(separator)
    |> String.reverse()
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end
