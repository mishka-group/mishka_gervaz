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
end
