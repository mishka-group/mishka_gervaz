defmodule MishkaGervaz.Table.Types.Filter.Text do
  @moduledoc """
  Text search filter type.

  Renders a text input that performs case-insensitive partial matching.

  ## Multi-field (Global) Search

  Use the `fields` option to search across multiple fields:

      filter :search, :text do
        fields [:name, :title, :description]

        ui do
          placeholder "Search everything..."
          icon "hero-magnifying-glass"
        end
      end

  This creates an OR query across all specified fields.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component
  require Ash.Query
  import MishkaGervaz.Helpers, only: [get_ui_label: 1]

  @impl true
  @spec render_input(map(), term(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(filter, value, ui) do
    extra = filter[:ui][:extra] || %{}

    ui.text_input(
      Map.merge(extra, %{
        __changed__: %{},
        name: filter.name,
        value: value || "",
        placeholder: filter[:ui][:placeholder],
        placeholder_label: get_ui_label(filter),
        phx_debounce: filter[:ui][:debounce],
        icon: filter[:ui][:icon],
        variant: :filter
      })
    )
  end

  @impl true
  @spec parse_value(term(), map()) :: String.t() | nil
  def parse_value(nil, _filter), do: nil
  def parse_value("", _filter), do: nil
  def parse_value(value, _filter) when is_binary(value), do: String.trim(value)
  def parse_value(value, _filter), do: value

  @impl true
  @spec build_query(Ash.Query.t(), atom(), term(), map()) :: Ash.Query.t()
  def build_query(query, field, value, filter \\ %{})

  def build_query(query, _field, value, %{fields: fields})
      when is_binary(value) and value != "" and is_list(fields) and fields != [] do
    build_multi_field_query(query, fields, value)
  end

  def build_query(query, field, value, _filter) when is_binary(value) and value != "" do
    Ash.Query.filter_input(query, %{field => %{contains: value}})
  end

  def build_query(query, _field, _value, _filter), do: query

  @spec build_multi_field_query(Ash.Query.t(), [atom()], String.t()) :: Ash.Query.t()
  defp build_multi_field_query(query, fields, value) do
    or_conditions =
      Enum.map(fields, fn field ->
        %{field => %{contains: value}}
      end)

    Ash.Query.filter_input(query, %{or: or_conditions})
  end
end
