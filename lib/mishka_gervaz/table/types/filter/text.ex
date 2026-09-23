defmodule MishkaGervaz.Table.Types.Filter.Text do
  @moduledoc """
  Text search filter type.

  Renders a text input that performs case-insensitive partial matching: the term is an
  `Ash.CiString`, which AshPostgres compiles to an escaped `ILIKE` and the ETS data layer compares
  without case — so "contact" finds "Contact us", and a `%` or `_` in the term is matched as itself.
  The relation loaders search the same way.

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

  See `MishkaGervaz.Table.Types.Filter` (registry),
  `MishkaGervaz.Table.Behaviours.FilterType`, and
  `MishkaGervaz.Table.Entities.Filter`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component

  require Ash.Query
  require Ash.Expr
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
    Ash.Query.filter(query, contains(^Ash.Expr.ref(field), ^Ash.CiString.new(value)))
  end

  def build_query(query, _field, _value, _filter), do: query

  @spec build_multi_field_query(Ash.Query.t(), [atom()], String.t()) :: Ash.Query.t()
  defp build_multi_field_query(query, fields, value) do
    term = Ash.CiString.new(value)

    condition =
      fields
      |> Enum.map(&Ash.Expr.expr(contains(^Ash.Expr.ref(&1), ^term)))
      |> Enum.reduce(&Ash.Expr.expr(^&2 or ^&1))

    Ash.Query.filter(query, ^condition)
  end
end
