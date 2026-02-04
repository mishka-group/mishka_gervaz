defmodule MishkaGervaz.Table.Types.Filter.Relation do
  @moduledoc """
  Relationship filter type for selecting related records.

  ## Modes
  - `:static` - Load all options at once (default, for small datasets)
  - `:load_more` - Paginated with "Load more" button
  - `:search` - Searchable single select
  - `:search_multi` - Searchable multi select

  ## Examples

      filter :category_id, type: :relation

      filter :site_id, type: :relation do
        mode :search_multi
        search_field :name
      end
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType

  @impl true
  def render_input(filter, value, ui) do
    mode = filter[:mode] || :static
    assigns = build_assigns(filter, value, mode)

    case mode do
      :static -> ui.select(assigns)
      :search -> ui.search_select(assigns)
      :search_multi -> ui.multi_select(assigns)
    end
  end

  @impl true
  def parse_value(nil, _filter), do: nil
  def parse_value("", _filter), do: nil
  def parse_value("__nil__", _filter), do: :nil_value

  def parse_value(values, %{mode: :search_multi}) when is_list(values) do
    case Enum.reject(values, &(&1 == "" or is_nil(&1))) do
      [] -> nil
      parsed -> parsed
    end
  end

  def parse_value(value, _filter), do: value

  @impl true
  def build_query(query, _field, nil), do: query
  def build_query(query, _field, ""), do: query

  def build_query(query, field, :nil_value) do
    Ash.Query.filter_input(query, %{field => %{is_nil: true}})
  end

  def build_query(query, field, values) when is_list(values) do
    Ash.Query.filter_input(query, %{field => %{in: values}})
  end

  def build_query(query, field, value) do
    Ash.Query.filter_input(query, %{field => %{eq: value}})
  end

  @impl true
  def build_query(query, _field, nil, _filter), do: query
  def build_query(query, _field, "", _filter), do: query

  def build_query(query, field, :nil_value, _filter) do
    Ash.Query.filter_input(query, %{field => %{is_nil: true}})
  end

  def build_query(query, field, values, %{mode: :search_multi}) when is_list(values) do
    Ash.Query.filter_input(query, %{field => %{in: values}})
  end

  def build_query(query, field, value, _filter) do
    Ash.Query.filter_input(query, %{field => %{eq: value}})
  end

  defp build_assigns(filter, value, mode) do
    base = %{
      __changed__: %{},
      name: filter.name,
      filter_name: filter.name,
      options: prepend_nil_option(filter[:options] || [], filter[:include_nil]),
      prompt: get_ui(filter, :prompt, "Select..."),
      placeholder: get_ui(filter, :placeholder),
      icon: get_ui(filter, :icon),
      variant: :filter,
      has_more?: filter[:has_more?] || false,
      loading?: filter[:loading?] || false,
      dropdown_open?: filter[:dropdown_open?] || false,
      myself: filter[:myself]
    }

    if mode == :search_multi do
      Map.merge(base, %{
        selected: normalize_selected(value),
        selected_options: filter[:selected_options] || [],
        min_chars: filter[:min_chars] || 2,
        debounce: get_ui(filter, :debounce, 300)
      })
    else
      Map.merge(base, %{
        value: value || "",
        min_chars: filter[:min_chars] || 2,
        debounce: get_ui(filter, :debounce, 300)
      })
    end
    |> Map.merge(get_ui(filter, :extra, %{}))
  end

  defp prepend_nil_option(options, nil), do: options
  defp prepend_nil_option(options, false), do: options
  defp prepend_nil_option(options, true), do: [{"(None)", "__nil__"} | options]

  defp prepend_nil_option(options, label) when is_binary(label),
    do: [{label, "__nil__"} | options]

  defp normalize_selected(nil), do: []
  defp normalize_selected(""), do: []

  defp normalize_selected(values) when is_list(values),
    do: Enum.reject(values, &(is_nil(&1) or &1 == ""))

  defp normalize_selected(value), do: [value]

  defp get_ui(filter, key, default \\ nil)
  defp get_ui(%{ui: ui}, key, default) when is_map(ui), do: Map.get(ui, key, default)
  defp get_ui(_, _key, default), do: default
end
