defmodule MishkaGervaz.Table.Types.Filter.DateRange do
  @moduledoc """
  Date range filter type.

  Renders two date inputs for filtering records within a date range.

  ## Example

      filter :created_at, :date_range, source: :inserted_at

      filter :updated_at, :date_range do
        source :updated_at
        ui do label "Last updated" end
      end

  See `MishkaGervaz.Table.Types.Filter` (registry),
  `MishkaGervaz.Table.Behaviours.FilterType`, and
  `MishkaGervaz.Table.Entities.Filter`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use MishkaGervaz.Messages
  require Ash.Query
  import Ash.Expr

  @doc """
  Draws the pair through the UI adapter's `date_range_container/1`: `<name>_from` and `<name>_to`
  date inputs in the filter style, each labelled "From" and "To" for assistive technology.

  `value` is the filter's current `%{from: _, to: _}`; either side may be missing, and anything
  that is not a map draws both inputs empty. The filter's `ui.extra` is merged into both inputs'
  assigns, and its `ui.icon` goes on the first.
  """
  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    range = if is_map(value), do: value, else: %{}
    extra = filter[:ui][:extra] || %{}
    from_label = dgettext("mishka_gervaz", "From")
    to_label = dgettext("mishka_gervaz", "To")

    from_input =
      ui.date_input(
        Map.merge(extra, %{
          __changed__: %{},
          name: "#{filter.name}_from",
          value: format_date(Map.get(range, :from)),
          placeholder: from_label,
          aria_label: from_label,
          icon: filter[:ui][:icon],
          search: true,
          variant: :filter
        })
      )

    to_input =
      ui.date_input(
        Map.merge(extra, %{
          __changed__: %{},
          name: "#{filter.name}_to",
          value: format_date(Map.get(range, :to)),
          placeholder: to_label,
          aria_label: to_label,
          search: true,
          variant: :filter
        })
      )

    ui.date_range_container(%{__changed__: %{}, from_input: from_input, to_input: to_input})
  end

  @impl true
  @spec parse_value(term(), map()) :: map() | nil
  def parse_value(nil, _filter), do: nil
  def parse_value(%{} = value, filter), do: parse_range(value, filter)
  def parse_value(_, _filter), do: nil

  @spec parse_range(map(), map()) :: map() | nil
  defp parse_range(%{from: from, to: to}, _filter) do
    parsed_from = parse_date(from)
    parsed_to = parse_date(to)

    cond do
      parsed_from && parsed_to -> %{from: parsed_from, to: parsed_to}
      parsed_from -> %{from: parsed_from}
      parsed_to -> %{to: parsed_to}
      true -> nil
    end
  end

  defp parse_range(_, _), do: nil

  @impl true
  @spec build_query(Ash.Query.t(), atom(), term(), map()) :: Ash.Query.t()
  def build_query(query, field, value, _filter \\ %{})

  def build_query(query, field, %{from: from, to: to}, _filter) do
    query
    |> Ash.Query.filter(^ref(field) >= ^from)
    |> Ash.Query.filter(^ref(field) <= ^to)
  end

  def build_query(query, field, %{from: from}, _filter) do
    Ash.Query.filter(query, ^ref(field) >= ^from)
  end

  def build_query(query, field, %{to: to}, _filter) do
    Ash.Query.filter(query, ^ref(field) <= ^to)
  end

  def build_query(query, _field, _value, _filter), do: query

  @spec parse_date(term()) :: Date.t() | nil
  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(%Date{} = date), do: date
  defp parse_date(_), do: nil

  @spec format_date(term()) :: String.t()
  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(value) when is_binary(value), do: value
  defp format_date(_), do: ""
end
