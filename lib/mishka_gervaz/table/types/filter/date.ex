defmodule MishkaGervaz.Table.Types.Filter.Date do
  @moduledoc """
  Date picker filter type.

  Renders a date input for date filtering.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component

  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    display_value =
      case value do
        %Date{} = date -> Date.to_iso8601(date)
        value when is_binary(value) -> value
        _ -> ""
      end

    extra = filter[:ui][:extra] || %{}

    ui.date_input(
      Map.merge(extra, %{
        __changed__: %{},
        name: filter.name,
        value: display_value,
        min: filter[:min],
        max: filter[:max],
        icon: filter[:ui][:icon],
        variant: :filter
      })
    )
  end

  @impl true
  @spec parse_value(term(), map()) :: Date.t() | nil
  def parse_value(nil, _filter), do: nil
  def parse_value("", _filter), do: nil

  def parse_value(value, _filter) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def parse_value(%Date{} = date, _filter), do: date
  def parse_value(_, _filter), do: nil

  @impl true
  @spec build_query(Ash.Query.t(), atom(), term(), map()) :: Ash.Query.t()
  def build_query(query, field, value, _filter \\ %{})

  def build_query(query, field, %Date{} = date, _filter) do
    Ash.Query.filter_input(query, %{field => %{eq: date}})
  end

  def build_query(query, _field, _value, _filter), do: query
end
