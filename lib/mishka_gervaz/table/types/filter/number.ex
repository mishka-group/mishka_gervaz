defmodule MishkaGervaz.Table.Types.Filter.Number do
  @moduledoc """
  Number input filter type.

  Renders a number input for numeric filtering.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component
  import MishkaGervaz.Helpers, only: [get_ui_label: 1]

  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    extra = filter[:ui][:extra] || %{}

    ui.number_input(
      Map.merge(extra, %{
        __changed__: %{},
        name: filter.name,
        value: value || "",
        placeholder: filter[:ui][:placeholder],
        placeholder_label: get_ui_label(filter),
        min: filter[:min],
        max: filter[:max],
        step: filter[:step],
        icon: filter[:ui][:icon],
        variant: :filter
      })
    )
  end

  @impl true
  @spec parse_value(term(), map()) :: number() | nil
  def parse_value(nil, _filter), do: nil
  def parse_value("", _filter), do: nil

  def parse_value(value, _filter) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      {num, _} -> num
      :error -> nil
    end
  end

  def parse_value(value, _filter) when is_number(value), do: value
  def parse_value(_, _filter), do: nil

  @impl true
  @spec build_query(Ash.Query.t(), atom(), term(), map()) :: Ash.Query.t()
  def build_query(query, field, value, _filter \\ %{})

  def build_query(query, field, value, _filter) when is_number(value) do
    Ash.Query.filter_input(query, %{field => %{eq: value}})
  end

  def build_query(query, _field, _value, _filter), do: query
end
