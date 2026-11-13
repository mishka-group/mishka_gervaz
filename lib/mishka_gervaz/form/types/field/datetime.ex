defmodule MishkaGervaz.Form.Types.Field.DateTime do
  @moduledoc """
  DateTime picker field type. Accepts both ISO-8601 naive and zoned strings, and the minutes a
  browser's `datetime-local` input sends (`"2024-09-09T22:45"`), which it completes to
  `"2024-09-09T22:45:00"`.

  `min` and `max` bound the times the picker offers and the save takes: days outside them are
  greyed out, and a value outside them gets a field error. A function is read each time, so
  `fn -> DateTime.utc_now() end` is always now. `ui` `step` sets the minutes between the times
  offered, and `first_day_of_week` the day each week of the calendar starts on.

  ## Example

      field :published_at, :datetime do
        min fn -> DateTime.utc_now() end

        ui do
          label "Publish time"
          step 15
        end
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use MishkaGervaz.Messages

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, config) when is_binary(value) and value != "" do
    value = with_seconds(value)

    case naive(value) do
      {:ok, at} -> within(value, at, config, :datetime)
      :error -> {:error, dgettext_noop("errors", "must be a valid date and time")}
    end
  end

  def validate(%Elixir.DateTime{} = value, config),
    do: within(value, Elixir.DateTime.to_naive(value), config, :datetime)

  def validate(%NaiveDateTime{} = value, config), do: within(value, value, config, :datetime)

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

  @doc """
  The `min` or `max` of a `:date` or `:datetime` field as its input's attribute, `"2024-09-09"` or
  `"2024-09-09T22:45:00"` by `kind`; `nil` when the field sets none. A function is called, so the
  bound is the one of this moment. A `min` time is taken to the start of its minute, the finest
  the picker offers, and a `Date` `max` to the end of its day.
  """
  @spec bound(map(), :min | :max, :date | :datetime) :: String.t() | nil
  def bound(field, side, kind) do
    case limit(field, side) do
      %NaiveDateTime{} = at -> value(NaiveDateTime.to_date(at), {at.hour, at.minute}, kind)
      nil -> nil
    end
  end

  @doc """
  `{:ok, value}` when the time `at` of `value` is within the `min` and `max` of `field`, compared by
  the day for a `:date` field; otherwise the field's error.
  """
  @spec within(term(), NaiveDateTime.t(), map(), :date | :datetime) ::
          {:ok, term()} | {:error, String.t()}
  def within(value, %NaiveDateTime{} = at, field, kind) do
    cond do
      before?(at, limit(field, :min), kind) -> {:error, dgettext_noop("errors", "is too early")}
      before?(limit(field, :max), at, kind) -> {:error, dgettext_noop("errors", "is too late")}
      true -> {:ok, value}
    end
  end

  @doc """
  The value of a `:date` or `:datetime` `field` for a day and a time of day, as `value/3` gives it,
  moved to the field's `min` or `max` when it falls outside them.
  """
  @spec clamp(map(), Date.t(), {0..23, 0..59}) :: String.t()
  def clamp(%{type: kind} = field, %Date{} = day, {hour, minute} = time) do
    at = NaiveDateTime.new!(day, Time.new!(hour, minute, 0))

    cond do
      before?(at, limit(field, :min), kind) -> bound(field, :min, kind)
      before?(limit(field, :max), at, kind) -> bound(field, :max, kind)
      true -> value(day, time, kind)
    end
  end

  defp before?(_at, nil, _kind), do: false
  defp before?(nil, _at, _kind), do: false

  defp before?(at, other, :date),
    do: Date.before?(NaiveDateTime.to_date(at), NaiveDateTime.to_date(other))

  defp before?(at, other, :datetime), do: NaiveDateTime.before?(at, other)

  defp limit(field, side) do
    case Map.get(field || %{}, side) do
      fun when is_function(fun, 0) -> edge(fun.(), side)
      other -> edge(other, side)
    end
  end

  defp edge(%Date{} = day, :min), do: NaiveDateTime.new!(day, ~T[00:00:00])
  defp edge(%Date{} = day, :max), do: NaiveDateTime.new!(day, ~T[23:59:59])
  defp edge(%Elixir.DateTime{} = at, side), do: at |> Elixir.DateTime.to_naive() |> edge(side)

  defp edge(%NaiveDateTime{} = at, :min),
    do: %{NaiveDateTime.truncate(at, :second) | second: 0}

  defp edge(%NaiveDateTime{} = at, :max), do: NaiveDateTime.truncate(at, :second)
  defp edge(_none, _side), do: nil

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
