defmodule MishkaGervaz.Table.Behaviours.ColumnType do
  @moduledoc """
  Behaviour for column type renderers.

  Implement this behaviour to create custom column types that render
  values in specific ways (badges, links, colors, etc.).

  ## Example

      defmodule MyApp.ColumnTypes.Color do
        @behaviour MishkaGervaz.Table.Behaviours.ColumnType
        use Phoenix.Component

        @impl true
        def render(value, _column, _record, _ui) do
          assigns = %{value: value}

          ~H\"""
          <div class="w-6 h-6 rounded" style={"background: \#{@value}"}></div>
          \"""
        end
      end

  Then use in DSL:

      column :background_color, type: MyApp.ColumnTypes.Color
  """

  @doc """
  Render the column cell value.

  ## Parameters

  - `value` - The value to render (extracted from record based on column source)
  - `column` - Column configuration map from DSL
  - `record` - The full record (for accessing other fields if needed)
  - `ui` - UI adapter module for consistent styling

  ## Returns

  Phoenix.LiveView.Rendered.t()
  """
  @callback render(
              value :: any(),
              column :: map(),
              record :: map(),
              ui :: module()
            ) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Optional: Return CSS class for the cell.
  """
  @callback cell_class(column :: map()) :: String.t() | nil

  @optional_callbacks [cell_class: 1]
end
