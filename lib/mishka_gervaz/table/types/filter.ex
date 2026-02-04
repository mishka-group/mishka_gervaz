defmodule MishkaGervaz.Table.Types.Filter do
  @moduledoc """
  Built-in filter type registry.

  Provides lookup for built-in filter types by atom name.
  Custom filter types can be used directly by passing the module.

  ## Built-in Types

  - `:text` - Text search input (default)
  - `:select` - Dropdown select
  - `:boolean` - Checkbox
  - `:number` - Number input
  - `:date` - Date picker
  - `:date_range` - Date range picker
  - `:relation` - Relationship select (auto-loads options)

  ## Usage in DSL

      filters do
        filter :name                           # Auto-detects type (text)
        filter :status, type: :select          # Built-in type
        filter :created_at, type: :date_range  # Built-in type
        filter :category, type: MyApp.TreeFilter # Custom type
      end
  """

  alias MishkaGervaz.Table.Types.Filter

  use MishkaGervaz.Table.Behaviours.TypeRegistry,
    builtin: %{
      text: Filter.Text,
      select: Filter.Select,
      boolean: Filter.Boolean,
      number: Filter.Number,
      date: Filter.Date,
      date_range: Filter.DateRange,
      relation: Filter.Relation
    },
    default: Filter.Text

  @doc """
  Resolve filter type module from filter configuration.

  Checks in order:
  1. If type is a module with `render_input/3`, use it directly
  2. If type is an atom, look up in built-in registry
  3. Otherwise, default to Text filter

  ## Examples

      iex> MishkaGervaz.Table.Types.Filter.resolve_type(%{type: :select})
      MishkaGervaz.Table.Types.Filter.Select

      iex> MishkaGervaz.Table.Types.Filter.resolve_type(%{})
      MishkaGervaz.Table.Types.Filter.Text
  """
  @impl true
  @spec resolve_type(map()) :: module()
  def resolve_type(filter) do
    filter_type = Map.get(filter, :type, :text)

    cond do
      is_atom(filter_type) and function_exported?(filter_type, :render_input, 3) -> filter_type
      is_atom(filter_type) -> get_or_passthrough(filter_type)
      true -> default()
    end
  end
end
