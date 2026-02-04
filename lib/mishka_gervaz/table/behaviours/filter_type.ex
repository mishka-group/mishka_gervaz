defmodule MishkaGervaz.Table.Behaviours.FilterType do
  @moduledoc """
  Behaviour for filter type implementations.

  Implement this behaviour to create custom filter inputs and query logic.

  ## Example

      defmodule MyApp.FilterTypes.DateRange do
        @behaviour MishkaGervaz.Table.Behaviours.FilterType
        use Phoenix.Component
        import Ash.Expr

        @impl true
        def render_input(filter, value, ui) do
          assigns = %{filter: filter, value: value || %{}, ui: ui}
          ~H\"\"\"
          <div class="flex gap-2">
            {@ui.date_input(%{name: "\#{@filter.name}_from", value: @value[:from]})}
            <span class="self-center">to</span>
            {@ui.date_input(%{name: "\#{@filter.name}_to", value: @value[:to]})}
          </div>
          \"\"\"
        end

        @impl true
        def parse_value(%{"from" => from, "to" => to}, _filter) do
          %{from: Date.from_iso8601!(from), to: Date.from_iso8601!(to)}
        end
        def parse_value(_, _), do: nil

        @impl true
        def build_query(query, field, %{from: from, to: to}) do
          query
          |> Ash.Query.filter(^ref(field) >= ^from)
          |> Ash.Query.filter(^ref(field) <= ^to)
        end
      end

  Then use in DSL:

      filter :created_at, type: MyApp.FilterTypes.DateRange
  """

  @doc """
  Render the filter input element.

  ## Parameters

  - `filter` - Filter configuration map from DSL
  - `value` - Current filter value (parsed)
  - `ui` - UI adapter module for consistent styling
  """
  @callback render_input(
              filter :: map(),
              value :: any(),
              ui :: module()
            ) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Parse raw form params into the filter value.

  Receives the raw string value(s) from the form and returns
  the parsed value that will be passed to build_query.
  """
  @callback parse_value(raw :: any(), filter :: map()) :: any()

  @doc """
  Apply the filter to an Ash query.

  ## Parameters

  - `query` - The Ash.Query to filter
  - `field` - The field name (atom)
  - `value` - The parsed filter value
  """
  @callback build_query(
              query :: Ash.Query.t(),
              field :: atom(),
              value :: any()
            ) :: Ash.Query.t()

  @doc """
  Apply the filter to an Ash query with full filter context.

  Use this when you need access to the full filter config (e.g., for multi-field search).

  ## Parameters

  - `query` - The Ash.Query to filter
  - `field` - The field name (atom)
  - `value` - The parsed filter value
  - `filter` - Full filter configuration map
  """
  @callback build_query(
              query :: Ash.Query.t(),
              field :: atom(),
              value :: any(),
              filter :: map()
            ) :: Ash.Query.t()

  @doc """
  Optional: Return label for the filter.
  """
  @callback label(filter :: map()) :: String.t()

  @optional_callbacks [label: 1, build_query: 4]
end
