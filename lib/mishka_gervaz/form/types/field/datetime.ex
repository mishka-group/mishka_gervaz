defmodule MishkaGervaz.Form.Types.Field.DateTime do
  @moduledoc """
  DateTime picker field type. Accepts both ISO-8601 naive and zoned strings, and the minutes a
  browser's `datetime-local` input sends (`"2024-09-09T22:45"`), which it completes to
  `"2024-09-09T22:45:00"`.

  ## Example

      field :published_at, :datetime do
        ui do label "Publish time" end
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use MishkaGervaz.Messages

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config) when is_binary(value) and value != "" do
    value = with_seconds(value)

    cond do
      match?({:ok, _}, NaiveDateTime.from_iso8601(value)) -> {:ok, value}
      match?({:ok, _, _}, DateTime.from_iso8601(value)) -> {:ok, value}
      true -> {:error, dgettext_noop("errors", "must be a valid date and time")}
    end
  end

  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config) when is_binary(value), do: with_seconds(value)
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: value |> String.trim() |> with_seconds()
  def sanitize(value, _config), do: value

  defp with_seconds(
         <<_date::binary-size(10), sep, _hour::binary-size(2), ?:, _minute::binary-size(2)>> =
           value
       )
       when sep in [?T, ?\s],
       do: value <> ":00"

  defp with_seconds(value), do: value

  @impl true
  def default_ui, do: %{type: :datetime}

  @doc """
  The day and the time of day a value holds — a `DateTime`, a `NaiveDateTime`, a `Date` or an
  ISO-8601 string — as `{date, {hour, minute}}`; `{nil, {0, 0}}` for a value that is none of them.
  """
  @spec parts(term()) :: {Date.t() | nil, {0..23, 0..59}}
  def parts(%struct{} = value) when struct in [Elixir.DateTime, NaiveDateTime],
    do: {struct.to_date(value), {value.hour, value.minute}}

  def parts(%Date{} = date), do: {date, {0, 0}}

  def parts(value) when is_binary(value) do
    with :error <- naive(with_seconds(String.trim(value))),
         {:ok, date} <- Date.from_iso8601(String.trim(value)) do
      {date, {0, 0}}
    else
      {:ok, %NaiveDateTime{} = at} -> parts(at)
      _none -> {nil, {0, 0}}
    end
  end

  def parts(_value), do: {nil, {0, 0}}

  @doc """
  The value of a `:datetime` field (`"2024-09-09T22:45:00"`) or a `:date` field (`"2024-09-09"`)
  for a day and a time of day.
  """
  @spec value(Date.t(), {0..23, 0..59}, :datetime | :date) :: String.t()
  def value(%Date{} = date, _time, :date), do: Date.to_iso8601(date)

  def value(%Date{} = date, {hour, minute}, :datetime),
    do: date |> NaiveDateTime.new!(Time.new!(hour, minute, 0)) |> NaiveDateTime.to_iso8601()

  defp naive(text) do
    case NaiveDateTime.from_iso8601(text) do
      {:ok, at} -> {:ok, at}
      {:error, _} -> zoned(text)
    end
  end

  defp zoned(text) do
    case Elixir.DateTime.from_iso8601(text) do
      {:ok, at, _offset} -> {:ok, Elixir.DateTime.to_naive(at)}
      {:error, _} -> :error
    end
  end
end
