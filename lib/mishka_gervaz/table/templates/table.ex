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

  See `MishkaGervaz.Table.Behaviours.Template`,
  `MishkaGervaz.Table.Templates.Shared` (shared render helpers),
  `MishkaGervaz.Table.Templates.MediaGallery`, and
  `MishkaGervaz.Table.Web.Renderer`.
  """

  use MishkaGervaz.Table.Behaviours.Template
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers,
    only: [resolve_label: 1, dynamic_component: 1, get_visible_columns: 2, accessible?: 2]

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Types
  alias Phoenix.LiveView.JS

  @doc false
  def pagination_type(static) do
    get_in(static.config, [:pagination, :type]) || :numbered
  end

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

    is_infinite_scroll? =
      pagination_type(static) == :infinite and state.has_more?

    viewport_event = if is_infinite_scroll?, do: "load_more", else: nil

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
      |> assign(:infinite_scroll?, is_infinite_scroll?)
      |> assign(:viewport_event, viewport_event)
      |> assign_new(:before_table, fn -> nil end)
      |> assign_new(:rail, fn -> nil end)
      |> assign_new(:filter_actions, fn -> nil end)

    ~H"""
    <div id={@static.id} class="mishka-gervaz-table">
      {render_notices_at(assigns, :table_top)}
      {render_notices_at(assigns, :before_header)}
      {render_chrome_header(assigns)}
      {render_notices_at(assigns, :after_header)}

      <div
        :if={@state.has_initial_data? or @state.loading == :loaded}
        class={Shared.rail_class(@rail, :grid)}
      >
        <div class={Shared.rail_class(@rail, :top)}>
          {render_notices_at(assigns, :before_filters)}
          <.render_filters
            :if={@show_filters}
            static={@static}
            state={@state}
            myself={@myself}
            filter_actions={@filter_actions}
          />
          {render_notices_at(assigns, :after_filters)}
        </div>

        <div :if={@rail not in [nil, []]} class={Shared.rail_class(@rail, :rail)}>
          {render_slot(@rail)}
        </div>

        <div class={Shared.rail_class(@rail, :bottom)}>
          {render_notices_at(assigns, :before_bulk_actions)}
          <.render_bulk_actions
            :if={@show_bulk_actions}
            static={@static}
            state={@state}
            myself={@myself}
          />
          {render_notices_at(assigns, :after_bulk_actions)}

          <div :if={@show_template_switcher} class="mb-[14px] flex justify-end">
            <Shared.render_template_switcher
              switchable_templates={@static.switchable_templates}
              current_template={@state.template}
              ui_adapter={@static.ui_adapter}
              myself={@myself}
            />
          </div>

          {render_notices_at(assigns, :before_table)}
          <%= if @before_table do %>
            {render_slot(@before_table)}
          <% end %>

          <div
            :if={not @empty?}
            class="relative isolate overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden rounded-[16px] border border-[#ecebe6] bg-white shadow-[0_1px_2px_rgba(30,28,24,0.04)] max-[980px]:overflow-visible! max-[980px]:rounded-none! max-[980px]:border-0! max-[980px]:bg-transparent! max-[980px]:shadow-none!"
          >
            <.render_loading_overlay
              :if={
                @state.has_initial_data? and @state.loading == :loading and
                  @state.loading_type == :reset
              }
              static={@static}
              state={@state}
            />
            <div class={container_classes(@static)}>
              <.render_header
                static={@static}
                state={@state}
                show_checkboxes={@show_checkboxes}
                show_expand={@show_expand}
                show_actions={@show_actions}
                features={@features}
                myself={@myself}
              />
              <div
                id={"#{@static.stream_name}"}
                phx-update="stream"
                class={row_group_classes(@static)}
              >
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
              </div>
            </div>
          </div>

          <div
            :if={@infinite_scroll?}
            id={@static.id <> "-infinite-trigger"}
            phx-viewport-bottom={@viewport_event}
            phx-target={@myself}
            class="flex items-center justify-center gap-2 py-6 text-[12.5px] font-medium text-[#a8a5a0]"
          >
            <span class="hero-arrow-down-circle w-4 h-4 animate-bounce"></span>
            <span>{dgettext("mishka_gervaz", "Scroll for more")}</span>
          </div>

          {render_notices_at(assigns, :after_table)}

          {render_notices_at(assigns, :empty_state)}
          <.render_empty :if={@empty?} static={@static} state={@state} myself={@myself} />

          {render_notices_at(assigns, :before_pagination)}
          <.render_pagination :if={@show_pagination} static={@static} state={@state} myself={@myself} />
          {render_notices_at(assigns, :after_pagination)}

          {render_notices_at(assigns, :table_bottom)}
        </div>
      </div>

      {render_chrome_footer(assigns)}
    </div>
    """
  end

  @doc false
  def render_chrome_header(assigns) do
    case assigns.static.header do
      nil ->
        ~H""

      header ->
        if chrome_visible?(header, assigns.state) do
          do_render_chrome_header(assigns, header)
        else
          ~H""
        end
    end
  end

  defp do_render_chrome_header(assigns, header) do
    case header.render do
      fun when is_function(fun, 1) ->
        fun.(assigns)

      fun when is_function(fun, 2) ->
        fun.(assigns, assigns.state)

      _ ->
        title = resolve_dynamic(header.title, assigns.state)
        description = resolve_dynamic(header.description, assigns.state)

        if is_nil(title) and is_nil(description) do
          ~H""
        else
          assigns =
            assigns
            |> assign(:header_title, title)
            |> assign(:header_description, description)
            |> assign(:header_icon, header.icon)
            |> assign(:header_class, header.class)
            |> assign(:ui, assigns.static.ui_adapter)

          ~H"""
          <.dynamic_component
            module={@ui}
            function={:form_header}
            title={@header_title}
            description={@header_description}
            icon={@header_icon}
            class={@header_class}
          />
          """
        end
    end
  end

  @doc false
  def render_chrome_footer(assigns) do
    case assigns.static.footer do
      nil ->
        ~H""

      footer ->
        if chrome_visible?(footer, assigns.state) do
          do_render_chrome_footer(assigns, footer)
        else
          ~H""
        end
    end
  end

  defp do_render_chrome_footer(assigns, footer) do
    case footer.render do
      fun when is_function(fun, 1) ->
        fun.(assigns)

      fun when is_function(fun, 2) ->
        fun.(assigns, assigns.state)

      _ ->
        content = resolve_dynamic(footer.content, assigns.state)

        if is_nil(content) do
          ~H""
        else
          assigns =
            assigns
            |> assign(:footer_content, content)
            |> assign(:footer_class, footer.class)
            |> assign(:ui, assigns.static.ui_adapter)

          ~H"""
          <.dynamic_component
            module={@ui}
            function={:form_footer}
            content={@footer_content}
            class={@footer_class}
          />
          """
        end
    end
  end

  @doc false
  def render_notices_at(assigns, position) do
    notices =
      assigns.static.notices
      |> Enum.filter(&(&1.position == position))
      |> Enum.filter(&notice_visible?(&1, assigns.state, assigns))

    assigns = assign(assigns, :notices_at_position, notices)

    ~H"""
    <%= for notice <- @notices_at_position do %>
      {render_notice(assigns, notice)}
    <% end %>
    """
  end

  defp render_notice(assigns, notice) do
    case notice.render do
      fun when is_function(fun, 1) ->
        assigns
        |> assign(:notice, notice)
        |> fun.()

      fun when is_function(fun, 2) ->
        assigns_with = assign(assigns, :notice, notice)
        fun.(assigns_with, assigns.state)

      _ ->
        title = resolve_dynamic(notice.title, assigns.state)
        content = resolve_dynamic(notice.content, assigns.state)
        notice_ui = notice.ui || %{}

        assigns =
          assigns
          |> assign(:notice_type, notice.type)
          |> assign(:notice_title, title)
          |> assign(:notice_content, content)
          |> assign(:notice_icon, notice.icon)
          |> assign(:notice_dismissible, notice.dismissible)
          |> assign(:notice_name, notice.name)
          |> assign(:notice_class, Map.get(notice_ui, :class))
          |> assign(:ui, assigns.static.ui_adapter)

        ~H"""
        <div class="mb-4">
          <.dynamic_component
            module={@ui}
            function={:alert}
            type={@notice_type}
            title={@notice_title}
            content={@notice_content}
            icon={@notice_icon}
            dismissible={@notice_dismissible}
            dismiss_event="dismiss_notice"
            dismiss_value={to_string(@notice_name)}
            phx_target={@myself}
            class={@notice_class}
          />
        </div>
        """
    end
  end

  defp notice_visible?(notice, state, assigns) do
    cond do
      not chrome_visible?(notice, state) -> false
      MapSet.member?(state.dismissed_notices || MapSet.new(), notice.name) -> false
      not bind_to_active?(notice, state, assigns) -> false
      is_function(notice.show_when, 1) -> notice.show_when.(state)
      true -> true
    end
  end

  defp chrome_visible?(entity, state) do
    restricted_ok? =
      case Map.get(entity, :restricted) do
        true -> state.master_user?
        fun when is_function(fun, 1) -> not fun.(state)
        _ -> true
      end

    visible_ok? =
      case Map.get(entity, :visible) do
        false -> false
        fun when is_function(fun, 1) -> fun.(state)
        _ -> true
      end

    restricted_ok? and visible_ok?
  end

  defp bind_to_active?(%{bind_to: nil}, _state, _assigns), do: true

  defp bind_to_active?(%{bind_to: :no_results}, state, _assigns) do
    state.has_initial_data? and state.loading != :loading and result_empty?(state.records_result)
  end

  defp bind_to_active?(%{bind_to: :has_filters}, %{filter_values: values}, _assigns)
       when is_map(values) do
    Enum.any?(values, fn
      {_k, nil} -> false
      {_k, ""} -> false
      {_k, []} -> false
      {_k, %{}} -> false
      _ -> true
    end)
  end

  defp bind_to_active?(%{bind_to: :has_filters}, _state, _assigns), do: false

  defp bind_to_active?(%{bind_to: :has_selection}, state, _assigns) do
    select_all = Map.get(state, :select_all?, false) == true
    selected = Map.get(state, :selected_ids, MapSet.new())

    select_all or
      (is_struct(selected, MapSet) and MapSet.size(selected) > 0)
  end

  defp bind_to_active?(%{bind_to: :loading}, %{loading: loading}, _assigns),
    do: loading in [:initial, :loading]

  defp bind_to_active?(%{bind_to: :error}, %{loading: :error}, _assigns), do: true

  defp bind_to_active?(%{bind_to: :error}, %{records_result: %{failed: true}}, _assigns),
    do: true

  defp bind_to_active?(%{bind_to: :error}, %{records_result: %{failed: reason}}, _assigns)
       when not is_nil(reason),
       do: true

  defp bind_to_active?(%{bind_to: :error}, _state, _assigns), do: false

  defp bind_to_active?(%{bind_to: :archived_view}, %{archive_status: :archived}, _assigns),
    do: true

  defp bind_to_active?(%{bind_to: :archived_view}, _state, _assigns), do: false

  defp bind_to_active?(_, _, _), do: true

  defp result_empty?(%{ok?: true, result: %{data: %{results: results}}})
       when is_list(results),
       do: results == []

  defp result_empty?(%{ok?: true, result: %{results: results}}) when is_list(results),
    do: results == []

  defp result_empty?(%{ok?: true, result: results}) when is_list(results),
    do: results == []

  defp result_empty?(_), do: false

  defp resolve_dynamic(nil, _state), do: nil
  defp resolve_dynamic(value, _state) when is_binary(value), do: value
  defp resolve_dynamic(fun, _state) when is_function(fun, 0), do: fun.()
  defp resolve_dynamic(fun, state) when is_function(fun, 1), do: fun.(state)
  defp resolve_dynamic(value, _state), do: value

  @impl true
  def render_header(assigns) do
    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:name, "select_all")
      |> assign(:value, "all")
      |> assign(:checked, assigns.state.select_all?)
      |> assign(:class, "gervaz-select-all-checkbox")

    sortable_columns =
      if :sort in assigns.features, do: assigns.static.sortable_columns, else: []

    visible_columns = get_visible_columns(assigns.static.columns, assigns.state)

    sort_field_map = assigns.static.sort_field_map || %{}

    grid_template =
      grid_template_columns(
        assigns.show_expand,
        assigns.show_checkboxes,
        visible_columns,
        assigns.show_actions
      )

    assigns =
      assigns
      |> assign(:checkbox_assigns, checkbox_assigns)
      |> assign(:sortable_columns, sortable_columns)
      |> assign(:visible_columns, visible_columns)
      |> assign(:sort_field_map, sort_field_map)
      |> assign(:grid_template, grid_template)

    ~H"""
    <div
      id={"#{@static.stream_name}-thead"}
      class={[
        (@static.theme && @static.theme[:header_class]) ||
          "grid py-[14px] border-b border-[#ecebe6] bg-[#faf9f6]",
        "max-[980px]:hidden!"
      ]}
      style={"grid-template-columns: #{@grid_template};"}
    >
      <div :if={@show_checkboxes} class="pl-[16px]">
        <.dynamic_component
          module={@static.ui_adapter}
          function={:checkbox}
          id={@static.id <> "-select-all-checkbox"}
          phx-click={toggle_all_js(@state.select_all?, @static.id)}
          phx-target={@myself}
          {@checkbox_assigns}
        />
      </div>
      <div :if={@show_expand}></div>
      <div
        :for={column <- @visible_columns}
        class={header_cell_classes(column, @sortable_columns)}
        phx-click={if column.name in @sortable_columns, do: "sort", else: nil}
        phx-value-column={column.name}
        phx-target={@myself}
      >
        <div class="flex min-w-0 items-center gap-1">
          <span class="truncate">
            {resolve_label(column.label) || Phoenix.Naming.humanize(column.name)}
          </span>
          <.sort_indicator
            :if={column.name in @sortable_columns}
            column={column.name}
            sort_fields={@state.sort_fields}
            sort_field_map={@sort_field_map}
          />
        </div>
      </div>
      <div :if={@show_actions} class={["text-right", header_type()]}>
        {dgettext("mishka_gervaz", "Actions")}
      </div>
    </div>
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
    <div id={@id}>
      <div class={[
        "gervaz-row gervaz-row-custom p-4 border-b border-border"
        | row_classes(@static, @state, @record, @is_checked)
      ]}>
        {@custom_content}
      </div>
    </div>
    """
  end

  defp render_component_row(assigns, component) do
    assigns = assign(assigns, :override_component, component)

    ~H"""
    <div id={@id}>
      <div class={[
        "gervaz-row gervaz-row-component p-4 border-b border-border"
        | row_classes(@static, @state, @record, @is_checked)
      ]}>
        <.live_component
          module={@override_component}
          id={"#{@static.id}-row-override-#{@record.id}"}
          record={@record}
          columns={@static.columns}
          row_actions={@static.row_actions}
          static={@static}
          state={@state}
          ui_adapter={@static.ui_adapter}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  defp render_default_row(assigns) do
    is_expanded = assigns.show_expand && assigns.state.expanded_id == to_string(assigns.record.id)
    filtered_row_actions = Shared.non_accordion_actions(assigns.static.row_actions)

    grid_template =
      grid_template_columns(
        assigns.show_expand,
        assigns.show_checkboxes,
        assigns.visible_columns,
        assigns.show_actions
      )

    assigns =
      assigns
      |> assign(:is_expanded, is_expanded)
      |> assign(:filtered_row_actions, filtered_row_actions)
      |> assign(:grid_template, grid_template)

    ~H"""
    <div
      id={@id}
      class="gervaz-row-group max-[980px]:mb-3 max-[980px]:overflow-hidden max-[980px]:rounded-[14px] max-[980px]:border max-[980px]:border-[#ecebe6] max-[980px]:bg-white max-[980px]:shadow-[0_1px_3px_rgba(30,28,24,0.06)]"
    >
      <div
        class={[
          "gervaz-row grid py-[14px] items-center transition-colors max-[980px]:relative! max-[980px]:flex! max-[980px]:flex-col! max-[980px]:items-stretch! max-[980px]:gap-[12px] max-[980px]:p-4"
          | row_classes(@static, @state, @record, @is_checked)
        ]}
        style={"grid-template-columns: #{@grid_template};"}
      >
        <div :if={@show_checkboxes} class="flex items-center pl-[16px] max-[980px]:pl-0!">
          <.dynamic_component
            module={@static.ui_adapter}
            function={:checkbox}
            phx-click="toggle_select"
            phx-value-id={@record.id}
            phx-target={@myself}
            {@checkbox_assigns}
          />
        </div>
        <div
          :if={@show_expand}
          class="flex items-center max-[980px]:absolute max-[980px]:top-[12px] max-[980px]:right-[12px]"
        >
          <button
            phx-click="expand_row"
            phx-value-id={@record.id}
            phx-target={@myself}
            class={[
              "grid size-[26px] place-items-center text-[#a8a5a0] transition-transform duration-200 hover:text-[#5c5a54] max-[980px]:size-[30px] max-[980px]:rounded-[8px] max-[980px]:border max-[980px]:border-[#ecebe6] max-[980px]:bg-[#faf9f6]",
              @is_expanded && "[transform:rotate(90deg)]"
            ]}
          >
            <svg
              width="15"
              height="15"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="m9 6 6 6-6 6" />
            </svg>
          </button>
        </div>
        <div
          :for={column <- @visible_columns}
          class={[
            cell_classes(column),
            "overflow-hidden max-[980px]:flex! max-[980px]:flex-col! max-[980px]:items-start! max-[980px]:gap-1 max-[980px]:overflow-visible! max-[980px]:px-0!"
          ]}
        >
          <span class="hidden text-[10.5px] font-bold uppercase tracking-wide text-muted-foreground max-[980px]:block">
            {resolve_label(column.label) || Phoenix.Naming.humanize(column.name)}
          </span>
          <Shared.render_cell column={column} record={@record} static={@static} state={@state} />
        </div>
        <div :if={@show_actions} class="flex items-center justify-end px-[16px] max-[980px]:px-0!">
          <Shared.render_row_actions
            row_actions={@filtered_row_actions}
            record={@record}
            static={@static}
            state={@state}
            myself={@myself}
          />
        </div>
      </div>
      <div
        :if={@is_expanded}
        class="border-b border-[#f0efea] bg-[#fbfbfa] px-6 py-[22px] max-[980px]:border-b-0 max-[980px]:border-t max-[980px]:px-4 max-[980px]:py-[18px]"
      >
        <div class="mb-[18px] flex items-center justify-between">
          <span class="text-[13.5px] font-bold text-[#1b1a18]">
            {dgettext("mishka_gervaz", "Record Details")}
          </span>
          <button
            phx-click="close_expanded"
            phx-target={@myself}
            class="inline-flex items-center gap-[6px] text-[12px] font-semibold text-[#8a877f] transition-colors hover:text-[#1b1a18]"
          >
            <svg
              width="13"
              height="13"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
            {dgettext("mishka_gervaz", "Close")}
          </button>
        </div>
        <%= cond do %>
          <% @state.expanded_data && @state.expanded_data.loading -> %>
            <div class="flex items-center gap-2 text-[13px] font-medium text-[#8a877f]">
              <div class="size-4 animate-spin rounded-full border-2 border-[#e0ded7] border-t-[#5b57d6]">
              </div>
              {dgettext("mishka_gervaz", "Loading...")}
            </div>
          <% @state.expanded_data && @state.expanded_data.failed -> %>
            <div class="text-[13px] font-medium text-[#c0473d]">
              {dgettext("mishka_gervaz", "Failed to load data")}
            </div>
          <% @state.expanded_data && @state.expanded_data.ok? -> %>
            {expanded_content(@state.expanded_data.result)}
          <% true -> %>
            <div class="text-[13px] font-medium text-[#8a877f]">
              {dgettext("mishka_gervaz", "No data")}
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  @spec expanded_content(term()) :: term()
  defp expanded_content(%Phoenix.LiveView.Rendered{} = rendered), do: rendered
  defp expanded_content({:safe, _} = safe), do: safe
  defp expanded_content(content), do: Phoenix.HTML.raw(content)

  @doc """
  The default loading state: the table's own header, and a spinner where the rows will be.

  Without a state there is no header to draw, and this is the spinner alone.
  """
  @impl true
  def render_loading(assigns) do
    loading_text =
      (assigns[:static] && assigns.static.pagination_ui.loading_text) ||
        dgettext("mishka_gervaz", "Loading...")

    assigns = assign(assigns, :loading_text, loading_text)

    ~H"""
    <div class="mishka-gervaz-table">
      {@static && @state && render_chrome_header(assigns)}

      <div class="py-12 text-center">
        <div class="inline-block size-8 animate-spin rounded-full border-4 border-[#dcdbf5] border-t-[#5b57d6]">
        </div>
        <p class="mt-2 text-[12.5px] font-medium text-[#8a877f]">{@loading_text}</p>
      </div>
    </div>
    """
  end

  defp render_loading_overlay(assigns) do
    loading_text = assigns.static.pagination_ui.loading_text
    assigns = assign(assigns, :loading_text, loading_text)

    ~H"""
    <div class="absolute inset-0 bg-white/70 flex items-center justify-center z-20 min-h-[200px]">
      <div class="flex items-center gap-2 bg-white px-4 py-2 rounded-lg shadow-md">
        <div class="inline-block size-5 animate-spin rounded-full border-2 border-[#dcdbf5] border-t-[#5b57d6]">
        </div>
        <span class="text-[12.5px] font-medium text-[#5c5a54]">{@loading_text ||
          dgettext("mishka_gervaz", "Loading...")}</span>
      </div>
    </div>
    """
  end

  @impl true
  def render_filters(assigns) do
    Shared.render_filters(assigns)
  end

  defp sort_indicator(assigns) do
    {direction, position} =
      get_sort_info(assigns.column, assigns.sort_fields, assigns.sort_field_map)

    assigns = assigns |> assign(:direction, direction) |> assign(:position, position)

    ~H"""
    <span class="ml-1 inline-flex shrink-0 items-center">
      <%= cond do %>
        <% @direction == :asc -> %>
          <span class="text-[#5b57d6]">&#9650;</span>
        <% @direction == :desc -> %>
          <span class="text-[#5b57d6]">&#9660;</span>
        <% true -> %>
          <span class="text-[#c3c0b8]">&#9650;</span>
      <% end %>
      <span :if={@position} class="ml-0.5 text-[11px] text-[#5b57d6]">{@position}</span>
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

  defp container_classes(_static) do
    "min-[981px]:min-w-min"
  end

  defp row_group_classes(static) do
    options = static.template_options || default_options()

    [
      "divide-y divide-[#f4f3ee]",
      options[:striped] && "[&>div:nth-child(even)]:bg-muted/20"
    ]
    |> Enum.filter(& &1)
  end

  defp grid_template_columns(show_expand, show_checkboxes, visible_columns, show_actions) do
    column_tracks =
      visible_columns
      |> Enum.with_index()
      |> Enum.map(fn {column, index} -> column_track(column, index) end)

    [
      show_checkboxes && "44px",
      show_expand && "34px"
    ]
    |> Enum.filter(& &1)
    |> Kernel.++(column_tracks)
    |> Kernel.++(if show_actions, do: ["120px"], else: [])
    |> Enum.join(" ")
  end

  defp column_track(%{ui: %{width: width}}, _index) when is_binary(width), do: width
  defp column_track(column, index), do: type_track(Map.get(column, :type_module), index)

  defp type_track(Types.Column.Badge, _index), do: "minmax(95px,0.8fr)"
  defp type_track(Types.Column.Bars, _index), do: "minmax(105px,0.9fr)"
  defp type_track(Types.Column.Boolean, _index), do: "minmax(90px,0.7fr)"
  defp type_track(Types.Column.Number, _index), do: "minmax(90px,0.7fr)"
  defp type_track(Types.Column.Date, _index), do: "minmax(120px,1fr)"
  defp type_track(Types.Column.DateTime, _index), do: "minmax(150px,1.1fr)"
  defp type_track(Types.Column.Tags, _index), do: "minmax(140px,1.2fr)"
  defp type_track(Types.Column.Avatars, _index), do: "minmax(120px,1fr)"
  defp type_track(Types.Column.Link, _index), do: "minmax(140px,1.2fr)"
  defp type_track(_type_module, 0), do: "minmax(190px,1.7fr)"
  defp type_track(_type_module, _index), do: "minmax(0,1fr)"

  # Every header cell's type, the Actions cell's included.
  @header_type "px-[16px] text-[11px] font-bold tracking-[0.03em] text-[#8a877f]"

  defp header_type, do: @header_type

  defp header_cell_classes(column, sortable_columns) do
    base = "min-w-0 text-left " <> @header_type

    sortable_extra =
      if column.name in sortable_columns, do: " cursor-pointer", else: ""

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
      theme_row_class || (options[:hoverable] != false && "hover:bg-accent/50"),
      selected? && "bg-accent",
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
      _ -> "flex items-center min-w-0 px-[16px] text-sm text-foreground"
    end
  end

  defp toggle_all_js(current_select_all, scope) do
    js = JS.push("toggle_select_all")

    if current_select_all do
      Shared.uncheck_all(js, scope)
    else
      Shared.check_all_table(js, scope)
    end
  end
end
