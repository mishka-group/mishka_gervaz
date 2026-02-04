defmodule MishkaGervaz.Table.Behaviours.Template do
  @moduledoc """
  Behaviour for layout templates.

  Templates define HOW data is structured and arranged:
  - Table: Traditional rows and columns
  - MediaGallery: Image/file gallery with thumbnails
  - Kanban: Column-based board layout
  - List: Simple list layout

  Templates work together with UIAdapters:
  - Template = WHERE things go (structure/layout)
  - UIAdapter = HOW things look (styling/CSS)

  ## Creating a Custom Template

      defmodule MyApp.Templates.CustomTable do
        @behaviour MishkaGervaz.Table.Behaviours.Template
        use Phoenix.Component

        @impl true
        def name, do: :custom_table

        @impl true
        def label, do: "Custom Table"

        @impl true
        def icon, do: "hero-table-cells"

        @impl true
        def features, do: [:sort, :filter, :select, :paginate]

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <div class="my-custom-wrapper">
            {render_slot(@inner_block)}
          </div>
          \"\"\"
        end

        # ... implement other callbacks
      end

  ## Using in DSL

      mishka_gervaz do
        table do
          presentation do
            template MyApp.Templates.CustomTable
            switchable_templates [
              MishkaGervaz.Table.Templates.Table,
              MyApp.Templates.CustomTable
            ]
          end
        end
      end
  """

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()
  @type feature ::
          :sort
          | :filter
          | :select
          | :bulk_actions
          | :paginate
          | :export
          | :expand
          | :reorder
          | :inline_edit
  @type features :: :all | [feature()]

  @all_features [
    :sort,
    :filter,
    :select,
    :bulk_actions,
    :paginate,
    :export,
    :expand,
    :reorder,
    :inline_edit
  ]

  @doc """
  Returns the list of all valid features.
  """
  @spec all_features() :: [feature()]
  def all_features, do: @all_features

  @doc """
  Normalizes features to a list.

  Converts `:all` to the full list of features, validates feature atoms.

  ## Examples

      iex> normalize_features(:all)
      [:sort, :filter, :select, :bulk_actions, :paginate, :export, :expand, :reorder, :inline_edit]

      iex> normalize_features([:sort, :filter])
      [:sort, :filter]
  """
  @spec normalize_features(features()) :: [feature()]
  def normalize_features(:all), do: @all_features
  def normalize_features(features) when is_list(features), do: features

  @doc """
  Checks if a specific feature is enabled.

  ## Examples

      iex> feature_enabled?(:all, :sort)
      true

      iex> feature_enabled?([:filter, :paginate], :sort)
      false
  """
  @spec feature_enabled?(features(), feature()) :: boolean()
  def feature_enabled?(:all, _feature), do: true
  def feature_enabled?(features, feature) when is_list(features), do: feature in features

  @doc """
  Unique template identifier atom.

  Examples: `:table`, `:grid`, `:media_gallery`, `:kanban`
  """
  @callback name() :: atom()

  @doc """
  Human-readable label for UI display.

  Examples: "Table", "Grid View", "Media Gallery"
  """
  @callback label() :: String.t()

  @doc """
  Icon identifier for template switcher UI.

  Examples: "hero-table-cells", "hero-squares-2x2", "hero-photo"
  """
  @callback icon() :: String.t()

  @doc """
  Description of what this template is best used for.
  """
  @callback description() :: String.t()

  @doc """
  Features supported by this template.

  Can return `:all` for all features or a list of specific features.

  Possible features:
  - `:sort` - Column sorting
  - `:filter` - Filtering
  - `:select` - Row/item selection
  - `:bulk_actions` - Bulk actions on selected items
  - `:paginate` - Pagination
  - `:export` - Export to CSV/Excel
  - `:expand` - Expandable rows/cards
  - `:reorder` - Drag and drop reordering
  - `:inline_edit` - Inline editing

  ## Examples

      # All features
      def features, do: :all

      # Specific features
      def features, do: [:sort, :filter, :paginate]
  """
  @callback features() :: features()

  @doc """
  Default options for this template.

  Can include things like:
  - `:columns` - Number of grid columns
  - `:card_size` - Card size for grid
  - `:show_header` - Whether to show header
  """
  @callback default_options() :: keyword()

  @doc """
  Render the complete template wrapper.

  This is the main entry point. It should render:
  - Filters (if enabled)
  - The main content area (table/grid/etc.)
  - Pagination (if enabled)

  Assigns include:
  - `@state` - The table state
  - `@ui_adapter` - The UI adapter module
  - `@stream` - The data stream
  - `@columns` - Column configurations
  - `@filters` - Filter configurations
  - And more...
  """
  @callback render(assigns()) :: rendered()

  @doc """
  Render the header section (for tables: thead, for grids: toolbar, etc.)
  """
  @callback render_header(assigns()) :: rendered()

  @doc """
  Render a single item (row for table, card for grid, etc.)

  Assigns include:
  - `@record` - The data record
  - `@id` - The stream item ID
  - `@columns` - Column configurations
  - `@actions` - Available actions
  """
  @callback render_item(assigns()) :: rendered()

  @doc """
  Render the empty state when no records exist.
  """
  @callback render_empty(assigns()) :: rendered()

  @doc """
  Render the loading state.
  """
  @callback render_loading(assigns()) :: rendered()

  @doc """
  Render the error state.
  """
  @callback render_error(assigns()) :: rendered()

  @doc """
  Render pagination controls.
  """
  @callback render_pagination(assigns()) :: rendered()

  @doc """
  Render filters section. Optional - has default implementation.
  """
  @callback render_filters(assigns()) :: rendered()

  @doc """
  Render bulk actions bar. Optional - has default implementation.
  """
  @callback render_bulk_actions(assigns()) :: rendered()

  @doc """
  Render the template switcher UI. Optional - has default implementation.
  """
  @callback render_template_switcher(assigns()) :: rendered()

  @optional_callbacks [
    render_filters: 1,
    render_bulk_actions: 1,
    render_template_switcher: 1,
    render_loading: 1
  ]

  @doc """
  Use this module to get default implementations for optional callbacks.

      defmodule MyTemplate do
        use MishkaGervaz.Table.Behaviours.Template

        # Now you only need to implement required callbacks
      end
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Behaviours.Template
      use Phoenix.Component

      import MishkaGervaz.Table.Behaviours.Template, only: [get_cell_value: 2]

      def render_filters(assigns), do: MishkaGervaz.Table.Templates.Shared.render_filters(assigns)

      def render_bulk_actions(assigns),
        do: MishkaGervaz.Table.Templates.Shared.render_bulk_actions(assigns)

      def render_template_switcher(assigns),
        do: MishkaGervaz.Table.Templates.Shared.render_template_switcher(assigns)

      def render_loading(assigns), do: MishkaGervaz.Table.Templates.Shared.render_loading(assigns)

      defoverridable render_filters: 1,
                     render_bulk_actions: 1,
                     render_template_switcher: 1,
                     render_loading: 1
    end
  end

  @doc """
  Extract cell value from a record based on column source.

  Handles various source formats:
  - Atom: Direct field access
  - List: Multiple fields joined
  - Tuple: Relationship field access
  """
  @spec get_cell_value(map(), map() | atom()) :: any()
  def get_cell_value(record, %{source: source, default: default, separator: separator}) do
    value = extract_value(record, source)

    cond do
      is_nil(value) or value == "" -> default
      is_list(value) -> Enum.join(value, separator || " ")
      true -> value
    end
  end

  def get_cell_value(record, source) when is_atom(source) do
    Map.get(record, source)
  end

  @spec extract_value(map(), atom() | list() | {atom(), atom()}) :: any()
  defp extract_value(record, source) when is_atom(source) do
    Map.get(record, source)
  end

  defp extract_value(record, sources) when is_list(sources) do
    Enum.map(sources, &extract_value(record, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp extract_value(record, {relation, field}) when is_atom(relation) and is_atom(field) do
    case Map.get(record, relation) do
      nil -> nil
      %Ash.NotLoaded{} -> nil
      related -> Map.get(related, field)
    end
  end

  defp extract_value(_record, _source), do: nil
end
