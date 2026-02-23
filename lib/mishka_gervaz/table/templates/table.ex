defmodule MishkaGervaz.Table.Templates.Table do
  @moduledoc """
  Default table template with rows and columns layout.

  This is the traditional data table layout with:
  - Column headers with sorting
  - Row-based data display
  - Row selection checkboxes
  - Inline row actions

  ## Features
  - `:sort` - Click column headers to sort
  - `:filter` - Filter controls above table
  - `:select` - Row selection with checkboxes
  - `:bulk_actions` - Actions on selected rows
  - `:paginate` - Pagination controls
  - `:expand` - Expandable row details

  ## Performance
  Uses `@static.*` for columns, ui_adapter, etc. (no re-render on user interaction)
  Uses `@state.*` for page, filter_values, etc. (re-renders when changed)
  """

  use MishkaGervaz.Table.Behaviours.Template
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers,
    only: [resolve_label: 1, dynamic_component: 1, get_visible_columns: 2, accessible?: 2]

  alias MishkaGervaz.Table.Templates.Shared
  alias Phoenix.LiveView.JS

  @impl true
  def name, do: :table

  @impl true
  def label, do: "Table"

  @impl true
  def icon, do: "hero-table-cells"

  @impl true
  def description, do: "Traditional table layout with rows and columns"

  @impl true
  def features do
    [:sort, :filter, :select, :bulk_actions, :paginate, :expand, :inline_edit]
  end

  @impl true
  def default_options do
    [show_header: true, striped: false, hoverable: true, bordered: false, compact: false]
  end

  @impl true
  def render(assigns) do
    static = assigns.static
    state = assigns.state
    features = static.features

    show_checkboxes =
      :select in features and
        static.bulk_actions != [] and
        Shared.has_visible_bulk_actions?(static.bulk_actions, state.archive_status)

    accessible_filters = Enum.filter(static.filters, &accessible?(&1, state))

    show_filters =
      (accessible_filters != [] or state.supports_archive) and :filter in features

    show_pagination = :paginate in features
    show_bulk_actions = :bulk_actions in features and show_checkboxes

    show_template_switcher =
      static.switchable_templates != nil and static.switchable_templates != []

    has_accordion_action = Enum.any?(static.row_actions, &(&1[:type] == :accordion))

    show_expand = :expand in features and has_accordion_action

    show_actions =
      Shared.has_user_visible_actions?(static.row_actions, static.row_action_dropdowns, state)

    assigns =
      assigns
      |> assign(:show_checkboxes, show_checkboxes)
      |> assign(:show_filters, show_filters)
      |> assign(:show_pagination, show_pagination)
      |> assign(:show_bulk_actions, show_bulk_actions)
      |> assign(:show_template_switcher, show_template_switcher)
      |> assign(:show_expand, show_expand)
      |> assign(:show_actions, show_actions)
      |> assign(:features, features)

    ~H"""
    <div class="mishka-gervaz-table">
      <.render_initial_loading
        :if={!@state.has_initial_data? and @state.loading in [:initial, :loading]}
        static={@static}
        state={@state}
      />

      <div :if={@state.has_initial_data? or @state.loading == :loaded}>
        <.render_filters :if={@show_filters} static={@static} state={@state} myself={@myself} />

        <.render_bulk_actions
          :if={@show_bulk_actions}
          static={@static}
          state={@state}
          myself={@myself}
        />

        <Shared.render_template_switcher
          :if={@show_template_switcher}
          switchable_templates={@static.switchable_templates}
          current_template={@state.template}
          myself={@myself}
        />

        <div class="relative overflow-x-auto" style="isolation: isolate;">
          <.render_loading_overlay
            :if={
              @state.has_initial_data? and @state.loading == :loading and
                @state.loading_type == :reset
            }
            static={@static}
            state={@state}
          />
          <table class={table_classes(@static)}>
            <.render_header
              static={@static}
              state={@state}
              show_checkboxes={@show_checkboxes}
              show_expand={@show_expand}
              show_actions={@show_actions}
              features={@features}
              myself={@myself}
            />
            <tbody id={"#{@static.stream_name}"} phx-update="stream" class="divide-y divide-gray-200">
              <tr id={"#{@static.stream_name}-empty-state"} class="hidden only:table-row">
                <td colspan="100" class="px-4 py-12 text-center text-gray-500">
                  <span
                    :if={get_in(@static.config, [:empty_state, :icon])}
                    class={[
                      get_in(@static.config, [:empty_state, :icon]),
                      "block mx-auto mb-4 h-12 w-12"
                    ]}
                  >
                  </span>
                  {get_in(@static.config, [:empty_state, :message]) ||
                    dgettext("mishka_gervaz", "No records found")}
                </td>
              </tr>
              <.render_item
                :for={{id, record} <- @stream}
                id={id}
                record={record}
                static={@static}
                state={@state}
                show_checkboxes={@show_checkboxes}
                show_expand={@show_expand}
                show_actions={@show_actions}
                myself={@myself}
              />
            </tbody>
            <tbody
              :if={@state.expanded_id}
              id={"#{@static.id}-expanded-tbody"}
            >
              <tr
                id={"#{@static.id}-expanded-row"}
                class="bg-gray-50 border-b"
                phx-hook="ExpandedRow"
                data-after-id={"#{@static.stream_name}-#{@state.expanded_id}"}
              >
                <td
                  colspan={
                    length(get_visible_columns(@static.columns, @state)) +
                      if(@show_expand, do: 1, else: 0) + if(@show_checkboxes, do: 1, else: 0) +
                      if(@show_actions, do: 1, else: 0)
                  }
                  class="px-6 py-4"
                >
                  <div class="flex justify-between items-center mb-2">
                    <span class="font-semibold text-sm">
                      {dgettext("mishka_gervaz", "Record Details")}
                    </span>
                    <button
                      phx-click="close_expanded"
                      phx-target={@myself}
                      class="text-gray-500 hover:text-gray-700 text-sm"
                    >
                      ✕ {dgettext("mishka_gervaz", "Close")}
                    </button>
                  </div>
                  <%= cond do %>
                    <% @state.expanded_data && @state.expanded_data.loading -> %>
                      <div class="flex items-center gap-2 text-gray-500">
                        <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-900">
                        </div>
                        {dgettext("mishka_gervaz", "Loading...")}
                      </div>
                    <% @state.expanded_data && @state.expanded_data.failed -> %>
                      <div class="text-red-500">
                        {dgettext("mishka_gervaz", "Failed to load data")}
                      </div>
                    <% @state.expanded_data && @state.expanded_data.ok? -> %>
                      {Phoenix.HTML.raw(@state.expanded_data.result)}
                    <% true -> %>
                      <div class="text-gray-500">{dgettext("mishka_gervaz", "No data")}</div>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.render_empty :if={@empty?} static={@static} state={@state} myself={@myself} />

        <.render_pagination :if={@show_pagination} static={@static} state={@state} myself={@myself} />
      </div>
    </div>
    """
  end

  @impl true
  def render_header(assigns) do
    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:name, "select_all")
      |> assign(:value, "all")
      |> assign(:checked, assigns.state.select_all?)

    sortable_columns =
      if :sort in assigns.features, do: assigns.static.sortable_columns, else: []

    visible_columns = get_visible_columns(assigns.static.columns, assigns.state)

    sort_field_map = assigns.static.sort_field_map || %{}

    assigns =
      assigns
      |> assign(:checkbox_assigns, checkbox_assigns)
      |> assign(:sortable_columns, sortable_columns)
      |> assign(:visible_columns, visible_columns)
      |> assign(:sort_field_map, sort_field_map)

    ~H"""
    <thead class={(@static.theme && @static.theme[:header_class]) || "bg-gray-50"}>
      <tr>
        <th :if={@show_expand} class="w-8 px-2 py-3"></th>
        <th :if={@show_checkboxes} class="w-10 px-4 py-3">
          <.dynamic_component
            module={@static.ui_adapter}
            function={:checkbox}
            id="select-all-checkbox"
            phx-click={toggle_all_js(@state.select_all?)}
            phx-target={@myself}
            {@checkbox_assigns}
          />
        </th>
        <th
          :for={column <- @visible_columns}
          class={header_cell_classes(column, @sortable_columns)}
          phx-click={if column.name in @sortable_columns, do: "sort", else: nil}
          phx-value-column={column.name}
          phx-target={@myself}
        >
          <div class="flex items-center gap-1">
            <span>{resolve_label(column.label) || Phoenix.Naming.humanize(column.name)}</span>
            <.sort_indicator
              :if={column.name in @sortable_columns}
              column={column.name}
              sort_fields={@state.sort_fields}
              sort_field_map={@sort_field_map}
            />
          </div>
        </th>
        <th
          :if={@show_actions}
          class="w-24 px-4 py-3 text-right"
        >
          {dgettext("mishka_gervaz", "Actions")}
        </th>
      </tr>
    </thead>
    """
  end

  @impl true
  def render_item(assigns) do
    static = assigns.static
    state = assigns.state
    record = assigns.record
    record_id = record.id

    is_checked =
      if state.select_all? do
        not MapSet.member?(state.excluded_ids, record_id)
      else
        MapSet.member?(state.selected_ids, record_id)
      end

    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:name, "select_row")
      |> assign(:value, record_id)
      |> assign(:checked, is_checked)
      |> assign(:class, "gervaz-row-checkbox")

    row_overrides = get_in(static.config, [:row, :overrides]) || []
    matching_override = find_matching_override(row_overrides, record)
    visible_columns = get_visible_columns(static.columns, state)

    assigns =
      assigns
      |> assign(:checkbox_assigns, checkbox_assigns)
      |> assign(:is_checked, is_checked)
      |> assign(:matching_override, matching_override)
      |> assign(:visible_columns, visible_columns)

    case matching_override do
      %{render: render_fn} when is_function(render_fn, 3) ->
        render_custom_row(assigns, render_fn)

      %{component: component} when not is_nil(component) ->
        render_component_row(assigns, component)

      _ ->
        render_default_row(assigns)
    end
  end

  defp find_matching_override(nil, _record), do: nil
  defp find_matching_override([], _record), do: nil

  defp find_matching_override(overrides, record) do
    Enum.find(overrides, fn override ->
      case override[:condition] do
        condition_fn when is_function(condition_fn, 1) -> condition_fn.(record)
        _ -> false
      end
    end)
  end

  defp render_custom_row(assigns, render_fn) do
    custom_content = render_fn.(assigns, assigns.record, assigns.static.columns)
    assigns = assign(assigns, :custom_content, custom_content)

    ~H"""
    <tr
      id={@id}
      class={["gervaz-row gervaz-row-custom" | row_classes(@static, @state, @record, @is_checked)]}
    >
      {@custom_content}
    </tr>
    """
  end

  defp render_component_row(assigns, component) do
    assigns = assign(assigns, :override_component, component)

    ~H"""
    <tr
      id={@id}
      class={["gervaz-row gervaz-row-component" | row_classes(@static, @state, @record, @is_checked)]}
    >
      <.live_component
        module={@override_component}
        id={"row-override-#{@record.id}"}
        record={@record}
        columns={@static.columns}
        row_actions={@static.row_actions}
        static={@static}
        state={@state}
        ui_adapter={@static.ui_adapter}
        myself={@myself}
      />
    </tr>
    """
  end

  defp render_default_row(assigns) do
    is_expanded = assigns.show_expand && assigns.state.expanded_id == to_string(assigns.record.id)
    filtered_row_actions = Enum.reject(assigns.static.row_actions, &(&1[:type] == :accordion))

    assigns =
      assigns
      |> assign(:is_expanded, is_expanded)
      |> assign(:filtered_row_actions, filtered_row_actions)

    ~H"""
    <tr id={@id} class={["gervaz-row" | row_classes(@static, @state, @record, @is_checked)]}>
      <td :if={@show_expand} class="w-8 px-2 py-3 text-center">
        <button
          phx-click="expand_row"
          phx-value-id={@record.id}
          phx-target={@myself}
          class="text-gray-400 hover:text-gray-700 transition-transform duration-200"
          style={if @is_expanded, do: "transform: rotate(90deg)", else: ""}
        >
          &#9654;
        </button>
      </td>
      <td :if={@show_checkboxes} class="w-10 px-4 py-3">
        <.dynamic_component
          module={@static.ui_adapter}
          function={:checkbox}
          phx-click="toggle_select"
          phx-value-id={@record.id}
          phx-target={@myself}
          {@checkbox_assigns}
        />
      </td>
      <td :for={column <- @visible_columns} class={cell_classes(column)}>
        <Shared.render_cell column={column} record={@record} static={@static} state={@state} />
      </td>
      <td
        :if={@show_actions}
        class="px-4 py-3 text-right"
      >
        <Shared.render_row_actions
          row_actions={@filtered_row_actions}
          record={@record}
          static={@static}
          state={@state}
          myself={@myself}
        />
      </td>
    </tr>
    """
  end

  @impl true
  def render_empty(assigns) do
    empty_state = Map.get(assigns.static.config, :empty_state, %{})
    assigns = assign(assigns, :empty_state, empty_state)
    Shared.render_empty_state(assigns)
  end

  @impl true
  def render_loading(assigns) do
    loading_text =
      (assigns[:static] && assigns.static.pagination_ui.loading_text) ||
        dgettext("mishka_gervaz", "Loading...")

    assigns = assign(assigns, :loading_text, loading_text)

    ~H"""
    <div class="py-12 text-center">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-blue-500 border-t-transparent">
      </div>
      <p class="mt-2 text-gray-500">{@loading_text}</p>
    </div>
    """
  end

  defp render_initial_loading(assigns) do
    loading_text = assigns.static.pagination_ui.loading_text

    if function_exported?(assigns.static.ui_adapter, :loading, 1) do
      assigns = assign(assigns, :loading_text, loading_text)

      ~H"""
      <.dynamic_component module={@static.ui_adapter} function={:loading} type={:initial} />
      """
    else
      assigns = assign(assigns, :loading_text, loading_text)

      ~H"""
      <div class="py-12 text-center">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-blue-500 border-t-transparent">
        </div>
        <p class="mt-2 text-gray-500">{@loading_text || dgettext("mishka_gervaz", "Loading...")}</p>
      </div>
      """
    end
  end

  defp render_loading_overlay(assigns) do
    loading_text = assigns.static.pagination_ui.loading_text
    assigns = assign(assigns, :loading_text, loading_text)

    ~H"""
    <div class="absolute inset-0 bg-white/70 flex items-center justify-center z-20 min-h-[200px]">
      <div class="flex items-center gap-2 bg-white px-4 py-2 rounded-lg shadow-md">
        <div class="inline-block animate-spin rounded-full h-5 w-5 border-2 border-blue-500 border-t-transparent">
        </div>
        <span class="text-gray-600">{@loading_text || dgettext("mishka_gervaz", "Loading...")}</span>
      </div>
    </div>
    """
  end

  @impl true
  def render_filters(assigns) do
    Shared.render_filters(assigns)
  end

  @impl true
  def render_bulk_actions(assigns) do
    Shared.render_bulk_actions(assigns)
  end

  @impl true
  def render_error(assigns) do
    error_state = Map.get(assigns.static.config, :error_state, %{})
    assigns = assign(assigns, :error_state, error_state)
    Shared.render_error_state(assigns)
  end

  @impl true
  def render_pagination(assigns) do
    pagination_type = get_in(assigns.static.config, [:pagination, :type]) || :numbered

    assigns =
      assigns
      |> assign(:pagination_type, pagination_type)
      |> assign(:loading_text, assigns.static.pagination_ui.loading_text)
      |> assign(:load_more_label, assigns.static.pagination_ui.load_more_label)

    Shared.render_pagination(assigns)
  end

  defp sort_indicator(assigns) do
    {direction, position} =
      get_sort_info(assigns.column, assigns.sort_fields, assigns.sort_field_map)

    assigns = assigns |> assign(:direction, direction) |> assign(:position, position)

    ~H"""
    <span class="ml-1 inline-flex items-center">
      <%= cond do %>
        <% @direction == :asc -> %>
          <span class="text-blue-500">&#9650;</span>
        <% @direction == :desc -> %>
          <span class="text-blue-500">&#9660;</span>
        <% true -> %>
          <span class="text-gray-300">&#9650;</span>
      <% end %>
      <span :if={@position} class="text-xs text-blue-500 ml-0.5">{@position}</span>
    </span>
    """
  end

  defp get_sort_info(column, sort_fields, sort_field_map) do
    primary =
      case Map.get(sort_field_map, column) do
        [first | _] -> first
        _ -> column
      end

    case Enum.find_index(sort_fields, fn {f, _} -> f == primary end) do
      nil ->
        {nil, nil}

      index ->
        {_field, order} = Enum.at(sort_fields, index)
        position = if length(sort_fields) > 1, do: index + 1, else: nil
        {order, position}
    end
  end

  defp table_classes(static) do
    options = static.template_options || default_options()

    [
      "min-w-full divide-y divide-gray-200",
      options[:striped] && "table-striped",
      options[:bordered] && "border border-gray-200",
      options[:compact] && "table-compact"
    ]
    |> Enum.filter(& &1)
  end

  defp header_cell_classes(column, sortable_columns) do
    base = "px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"

    sortable_extra =
      if column.name in sortable_columns, do: " cursor-pointer hover:bg-gray-100", else: ""

    case column.ui do
      %{header_class: header_class} when not is_nil(header_class) -> header_class
      _ -> base <> sortable_extra
    end
  end

  defp row_classes(static, _state, record, selected?) do
    options = static.template_options || default_options()
    custom_class = get_custom_row_class(static, record)
    theme_row_class = static.theme && static.theme[:row_class]

    [
      theme_row_class || (options[:hoverable] != false && "hover:bg-gray-50"),
      selected? && "bg-blue-50",
      custom_class
    ]
    |> Enum.filter(& &1)
  end

  defp get_custom_row_class(static, record) do
    case get_in(static.config, [:row, :class, :apply]) do
      apply_fn when is_function(apply_fn, 1) -> apply_fn.(record)
      _ -> nil
    end
  end

  defp cell_classes(column) do
    case column.ui do
      %{class: class} when not is_nil(class) -> class
      _ -> "px-4 py-3 whitespace-nowrap text-sm text-gray-900"
    end
  end

  defp toggle_all_js(current_select_all) do
    js = JS.push("toggle_select_all")

    if current_select_all do
      Shared.uncheck_all(js)
    else
      Shared.check_all_table(js)
    end
  end
end
