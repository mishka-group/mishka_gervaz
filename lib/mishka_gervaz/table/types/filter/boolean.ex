defmodule MishkaGervaz.Table.Types.Filter.Boolean do
  @moduledoc """
  Boolean checkbox filter type.

  Renders a checkbox for true/false filtering.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component
  import MishkaGervaz.Helpers, only: [to_boolean: 1, get_ui_label: 1]

  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    extra = filter[:ui][:extra] || %{}

    ui.checkbox(
      Map.merge(extra, %{
        __changed__: %{},
        name: filter.name,
        value: "true",
        checked: to_boolean(value) == true,
        label: get_ui_label(filter),
        icon: filter[:ui][:icon],
        variant: :filter
      })
    )
  end

  @impl true
  @spec parse_value(term(), map()) :: boolean() | nil
  def parse_value(value, _filter), do: to_boolean(value)

  @impl true
  @spec build_query(Ash.Query.t(), atom(), term(), map()) :: Ash.Query.t()
  def build_query(query, field, value, _filter \\ %{})

  def build_query(query, field, true, _filter) do
    Ash.Query.filter_input(query, %{field => %{eq: true}})
  end

  def build_query(query, field, false, _filter) do
    Ash.Query.filter_input(query, %{field => %{eq: false}})
  end

  def build_query(query, _field, _value, _filter), do: query
end
