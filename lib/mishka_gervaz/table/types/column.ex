defmodule MishkaGervaz.Table.Types.Column do
  # Suppress macro-generated pattern match warning from TypeRegistry
  @dialyzer :no_match

  @moduledoc """
  Built-in column type registry.

  Provides lookup for built-in column types by atom name.
  Custom column types can be used directly by passing the module.

  ## Built-in Types

  - `:text` - Plain text (default)
  - `:boolean` - Boolean with checkmark/X icons
  - `:number` - Numeric values
  - `:date` - Date formatting
  - `:datetime` - DateTime formatting
  - `:uuid` - UUID with truncation
  - `:array` - Array/list values
  - `:badge` - Status badges with colors
  - `:link` - Clickable links

  ## Usage in DSL

      columns do
        column :name                          # Auto-detects type
        column :status, type: :badge          # Built-in type
        column :color, type: MyApp.ColorType  # Custom type
      end
  """

  alias MishkaGervaz.Table.Types.Column

  use MishkaGervaz.Table.Behaviours.TypeRegistry,
    builtin: %{
      text: {Column.Text, []},
      boolean: {Column.Boolean, [Ash.Type.Boolean]},
      number: {Column.Number, [Ash.Type.Integer, Ash.Type.Float, Ash.Type.Decimal]},
      date: {Column.Date, [Ash.Type.Date]},
      datetime:
        {Column.DateTime, [Ash.Type.DateTime, Ash.Type.UtcDatetime, Ash.Type.UtcDatetimeUsec]},
      uuid: {Column.UUID, [Ash.Type.UUID, Ash.Type.UUIDv7]},
      array: {Column.Array, [:__array__]},
      badge: {Column.Badge, []},
      link: {Column.Link, []}
    },
    default: Column.Text

  @doc """
  Resolve column type module from explicit type or Ash attribute.

  Checks in order:
  1. If type_module is already set (from DSL transform), use it
  2. If ui.type is set and is a module with `render/4`, use it directly
  3. If ui.type is set and is an atom, look up in built-in registry
  4. Otherwise, infer from Ash attribute type

  ## Examples

      iex> MishkaGervaz.Table.Types.Column.resolve_type(%{ui: %{type: :badge}}, %{})
      MishkaGervaz.Table.Types.Column.Badge

      iex> MishkaGervaz.Table.Types.Column.resolve_type(%{name: :active}, %{active: %{type: Ash.Type.Boolean}})
      MishkaGervaz.Table.Types.Column.Boolean
  """
  @impl true
  @spec resolve_type(map(), map()) :: module()
  def resolve_type(column, attributes) do
    existing_type_module = Map.get(column, :type_module)

    if existing_type_module do
      existing_type_module
    else
      explicit_type = get_ui_type(column)

      cond do
        is_atom(explicit_type) and explicit_type != nil and
            function_exported?(explicit_type, :render, 4) ->
          explicit_type

        is_atom(explicit_type) and explicit_type != nil ->
          get_or_passthrough(explicit_type)

        true ->
          attr = Map.get(attributes, column.name)
          infer_from_ash_type(attr)
      end
    end
  end

  @spec get_ui_type(map()) :: atom() | nil
  defp get_ui_type(%{ui: %{type: type}}), do: type
  defp get_ui_type(_), do: nil
end
