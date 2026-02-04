defmodule MishkaGervaz.Table.Types.Filter.Select do
  @moduledoc """
  Select dropdown filter type.

  Renders a dropdown with options. Options can be:
  - Static list from DSL
  - Auto-loaded from relationship
  - Loaded via custom function
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component
  import MishkaGervaz.Helpers, only: [humanize: 1]

  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    options = normalize_options(filter[:options] || [])
    extra = filter[:ui][:extra] || %{}

    ui.select(
      Map.merge(extra, %{
        __changed__: %{},
        name: filter.name,
        value: value || "",
        options: options,
        prompt: filter[:ui][:prompt],
        icon: filter[:ui][:icon],
        variant: :filter
      })
    )
  end

  @impl true
  @spec parse_value(term(), map()) :: term()
  def parse_value(nil, _filter), do: nil
  def parse_value("", _filter), do: nil
  def parse_value("__nil__", _filter), do: :nil_value
  def parse_value(value, _filter), do: value

  @impl true
  @spec build_query(Ash.Query.t(), atom(), term(), map()) :: Ash.Query.t()
  def build_query(query, field, value, _filter \\ %{})

  def build_query(query, field, :nil_value, _filter) do
    Ash.Query.filter_input(query, %{field => %{is_nil: true}})
  end

  def build_query(query, field, value, _filter) when value != nil and value != "" do
    Ash.Query.filter_input(query, %{field => %{eq: value}})
  end

  def build_query(query, _field, _value, _filter), do: query

  @spec normalize_options(list() | term()) :: list()
  defp normalize_options(options) when is_list(options) do
    Enum.map(options, fn
      {label, value} -> {label, value}
      atom when is_atom(atom) -> {humanize(atom), atom}
      value -> {to_string(value), value}
    end)
  end

  defp normalize_options(_), do: []
end
