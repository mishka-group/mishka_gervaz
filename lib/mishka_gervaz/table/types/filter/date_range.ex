defmodule MishkaGervaz.Table.Types.Filter.DateRange do
  @moduledoc """
  Date range filter type.

  Renders two date inputs for filtering records within a date range.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component
  require Ash.Query
  import Ash.Expr

  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    value = value || %{}
    extra = filter[:ui][:extra] || %{}

    assigns = %{
      __changed__: %{},
      filter: filter,
      from_value: format_date(value[:from]),
      to_value: format_date(value[:to]),
      ui: ui,
      icon: filter[:ui][:icon],
      extra: extra,
      container_class: filter[:ui][:container_class],
      separator_class: filter[:ui][:separator_class]
    }

    ~H"""
    {@ui.date_range_container(%{
      __changed__: %{},
      class: @container_class,
      separator_class: @separator_class,
      from_input:
        @ui.date_input(
          Map.merge(@extra, %{
            __changed__: %{},
            name: "#{@filter.name}_from",
            value: @from_value,
            placeholder: "From",
            icon: @icon,
            variant: :filter
          })
        ),
      to_input:
        @ui.date_input(
          Map.merge(@extra, %{
            __changed__: %{},
            name: "#{@filter.name}_to",
            value: @to_value,
            placeholder: "To",
            variant: :filter
          })
        )
    })}
    """
  end

  @impl true
  @spec parse_value(term(), map()) :: map() | nil
  def parse_value(nil, _filter), do: nil
  def parse_value(%{} = value, filter), do: parse_range(value, filter)

  def parse_value(params, filter) when is_map(params) do
    field_name = to_string(filter.name)
    from_value = Map.get(params, "#{field_name}_from")
    to_value = Map.get(params, "#{field_name}_to")

    parse_range(%{from: from_value, to: to_value}, filter)
  end

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
