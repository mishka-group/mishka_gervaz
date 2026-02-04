defmodule MishkaGervaz.Table.Templates.Shared do
  @moduledoc """
  Shared rendering functions used by all templates.

  These provide default implementations for common UI elements like
  filters, bulk actions, pagination, and template switcher.

  ## Performance Optimization

  All functions expect two key assigns:
  - `@static` - Same reference always (columns, filters, ui_adapter, etc.)
  - `@state` - Changes trigger re-render (page, filter_values, etc.)

  This separation allows LiveView to skip re-rendering static parts.
  """

  use Phoenix.Component
  use MishkaGervaz.Messages

  alias Phoenix.LiveView.JS

  import MishkaGervaz.Helpers,
    only: [
      dynamic_component: 1,
      to_boolean: 1,
      resolve_ui_label: 1,
      accessible?: 2,
      has_value?: 1,
      find_by_name: 2
    ]

  @doc """
  Unchecks all selection checkboxes and removes selection highlighting.
  """
  @spec uncheck_all(JS.t()) :: JS.t()
  def uncheck_all(js \\ %JS{}) do
    js
    |> JS.remove_attribute("checked", to: ".gervaz-row-checkbox")
    |> JS.remove_attribute("checked", to: ".gervaz-media-checkbox")
    |> JS.remove_attribute("checked", to: ".gervaz-select-all-checkbox")
    |> JS.remove_attribute("checked", to: "#select-all-checkbox")
    |> JS.remove_class("bg-blue-50", to: ".gervaz-row")
  end

  @doc """
  Checks all table row checkboxes and adds selection highlighting.
  """
  @spec check_all_table(JS.t()) :: JS.t()
  def check_all_table(js \\ %JS{}) do
    js
    |> JS.set_attribute({"checked", "checked"}, to: ".gervaz-row-checkbox")
    |> JS.add_class("bg-blue-50", to: ".gervaz-row")
  end

  @doc """
  Checks all media gallery checkboxes.
  """
  @spec check_all_gallery(JS.t()) :: JS.t()
  def check_all_gallery(js \\ %JS{}) do
    js
    |> JS.set_attribute({"checked", "checked"}, to: ".gervaz-media-checkbox")
    |> JS.set_attribute({"checked", "checked"}, to: ".gervaz-select-all-checkbox")
  end

  def render_filters(assigns) do
    static = assigns.static
    state = assigns.state
    filter_layout = static.filter_layout

    all_filters = merge_relation_filter_state(static.filters, state.relation_filter_state || %{})
    filters = Enum.filter(all_filters, &accessible?(&1, state))

    assigns =
      assigns
      |> assign(:filters, filters)
      |> assign(:all_filters, all_filters)
      |> assign(:has_active_filters, map_size(state.filter_values) > 0)
      |> assign(:layout, filter_layout)

    ~H"""
    <div :if={@filters != [] or @state.supports_archive} class="mb-4">
      <.render_filters_by_mode
        mode={Map.get(@layout, :mode, :inline)}
        filters={@filters}
        all_filters={@all_filters}
        has_active_filters={@has_active_filters}
        columns={Map.get(@layout, :columns, 4)}
        collapsible={Map.get(@layout, :collapsible, true)}
        collapsed={Map.get(@layout, :collapsed_default, false)}
        groups={Map.get(@layout, :groups, [])}
        state={@state}
        static={@static}
        myself={@myself}
      />
    </div>
    """
  end

  defp render_filters_by_mode(%{mode: :inline} = assigns) do
    ~H"""
    <div class={[@collapsible && "filter-collapsible"]}>
      <div class="flex items-center gap-4 mb-4">
        <.dynamic_component
          :if={@state.supports_archive}
          module={@static.ui_adapter}
          function={:archive_toggle}
          archive_status={@state.archive_status}
          myself={@myself}
        />
      </div>

      <form
        :if={@filters != []}
        phx-change="filter"
        phx-target={@myself}
        class={["grid gap-4", grid_cols(@columns)]}
      >
        <.render_filter
          :for={filter <- @filters}
          filter={filter}
          all_filters={@all_filters}
          state={@state}
          static={@static}
          myself={@myself}
        />
        <.dynamic_component
          :if={@has_active_filters}
          module={@static.ui_adapter}
          function={:filter_reset_button}
          label={dgettext("mishka_gervaz", "Clear filters")}
          class="text-sm text-gray-500 hover:text-gray-700 underline justify-self-start"
        />
      </form>
    </div>
    """
  end

  defp render_filters_by_mode(%{mode: :sidebar} = assigns) do
    ~H"""
    <div class="flex gap-4">
      <aside class="w-64 shrink-0 border-r pr-4">
        <.dynamic_component
          :if={@state.supports_archive}
          module={@static.ui_adapter}
          function={:archive_toggle}
          archive_status={@state.archive_status}
          myself={@myself}
        />

        <form :if={@filters != []} phx-change="filter" phx-target={@myself} class="space-y-4 mt-4">
          <.render_filter
            :for={filter <- @filters}
            filter={filter}
            all_filters={@all_filters}
            state={@state}
            static={@static}
            myself={@myself}
          />
          <.dynamic_component
            :if={@has_active_filters}
            module={@static.ui_adapter}
            function={:filter_reset_button}
            label={dgettext("mishka_gervaz", "Clear filters")}
            class="mt-4 text-sm text-gray-500 hover:text-gray-700 underline"
          />
        </form>
      </aside>
    </div>
    """
  end

  defp render_filters_by_mode(%{mode: mode} = assigns) when mode in [:modal, :drawer] do
    ~H"""
    <div class="flex items-center gap-4">
      <.dynamic_component
        :if={@state.supports_archive}
        module={@static.ui_adapter}
        function={:archive_toggle}
        archive_status={@state.archive_status}
        myself={@myself}
      />

      <.dynamic_component
        module={@static.ui_adapter}
        function={:button}
        type="button"
        label={dgettext("mishka_gervaz", "Filters")}
        icon="hero-funnel-solid"
        class="px-4 py-2 border rounded hover:bg-gray-50 flex items-center gap-2"
        phx-click="toggle_filters"
        phx-target={@myself}
      />

      <.dynamic_component
        :if={@has_active_filters}
        module={@static.ui_adapter}
        function={:button}
        type="button"
        label={dgettext("mishka_gervaz", "Clear filters")}
        class="text-sm text-gray-500 hover:text-gray-700 underline"
        phx-click="clear_filters"
        phx-target={@myself}
      />
    </div>
    """
  end

  defp render_filters_by_mode(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-4">
      <.dynamic_component
        :if={@state.supports_archive}
        module={@static.ui_adapter}
        function={:archive_toggle}
        archive_status={@state.archive_status}
        myself={@myself}
      />

      <form :if={@filters != []} phx-change="filter" phx-target={@myself} class="contents">
        <.render_filter
          :for={filter <- @filters}
          filter={filter}
          all_filters={@all_filters}
          state={@state}
          static={@static}
          myself={@myself}
        />
        <.dynamic_component
          :if={@has_active_filters}
          module={@static.ui_adapter}
          function={:filter_reset_button}
          label={dgettext("mishka_gervaz", "Clear filters")}
        />
      </form>
    </div>
    """
  end

  defp grid_cols(1), do: "grid-cols-1"
  defp grid_cols(2), do: "grid-cols-2"
  defp grid_cols(3), do: "grid-cols-3"
  defp grid_cols(4), do: "grid-cols-4"
  defp grid_cols(5), do: "grid-cols-5"
  defp grid_cols(6), do: "grid-cols-6"
  defp grid_cols(_), do: "grid-cols-4"

  defp render_filter(assigns) do
    %{filter: filter, all_filters: all_filters, state: state, static: static} = assigns

    disabled = filter_disabled?(filter, all_filters, state)
    disabled_prompt = if disabled, do: get_disabled_prompt(filter, all_filters), else: nil
    value = Map.get(state.filter_values, filter.name)

    assigns =
      assigns
      |> assign(:value, value)
      |> assign(:disabled, disabled)
      |> assign(:disabled_prompt, disabled_prompt)
      |> assign(:ui_adapter, static.ui_adapter)

    if disabled do
      render_disabled_filter(assigns)
    else
      render_enabled_filter(assigns)
    end
  end

  defp filter_disabled?(%{depends_on: nil}, _all_filters, _state), do: false

  defp filter_disabled?(%{depends_on: depends_on}, all_filters, state) do
    parent = find_by_name(all_filters, depends_on)

    cond do
      parent && parent.restricted == true && !state.master_user? -> false
      true -> !has_value?(Map.get(state.filter_values, depends_on))
    end
  end

  defp get_disabled_prompt(%{ui: %{disabled_prompt: prompt}}, _) when is_binary(prompt),
    do: prompt

  defp get_disabled_prompt(%{ui: %{disabled_prompt: prompt}}, _) when is_function(prompt, 0),
    do: prompt.()

  defp get_disabled_prompt(%{depends_on: depends_on}, all_filters) when not is_nil(depends_on) do
    parent_label =
      case find_by_name(all_filters, depends_on) do
        nil -> nil
        parent -> resolve_ui_label(parent)
      end

    field_name = parent_label || Phoenix.Naming.humanize(depends_on)
    dgettext("mishka_gervaz", "Select %{field} first", field: field_name)
  end

  defp get_disabled_prompt(_, _), do: dgettext("mishka_gervaz", "Select parent filter first")

  defp render_disabled_filter(assigns) do
    label = resolve_ui_label(assigns.filter)

    assigns = assign(assigns, :resolved_label, label)

    ~H"""
    <div>
      <label :if={@resolved_label} class="block text-sm font-medium mb-1 text-gray-400">
        {@resolved_label}
      </label>
      <div class="px-3 py-2 text-sm bg-gray-100 border border-gray-200 rounded text-gray-400 cursor-not-allowed">
        {@disabled_prompt}
      </div>
    </div>
    """
  end

  defp render_enabled_filter(assigns) do
    filter = assigns.filter

    case filter.type do
      :text ->
        placeholder =
          (filter.ui && filter.ui.placeholder) || dgettext("mishka_gervaz", "Search...")

        resolved_label = resolve_ui_label(filter)

        assigns =
          assigns
          |> assign(:name, filter.name)
          |> assign(:value, assigns.value || "")
          |> assign(:placeholder, placeholder)
          |> assign(:icon, filter.ui && filter.ui.icon)
          |> assign(:resolved_label, resolved_label)

        ~H"""
        <div>
          <label :if={@resolved_label} class="block text-sm font-medium mb-1">
            {@resolved_label}
          </label>
          <.dynamic_component module={@ui_adapter} function={:text_input} {assigns} />
        </div>
        """

      :select ->
        resolved_label = resolve_ui_label(filter)

        assigns =
          assigns
          |> assign(:name, filter.name)
          |> assign(:options, filter.options || [])
          |> assign(
            :prompt,
            (filter.ui && filter.ui.prompt) || dgettext("mishka_gervaz", "Select...")
          )
          |> assign(:icon, filter.ui && filter.ui.icon)
          |> assign(:resolved_label, resolved_label)

        ~H"""
        <div>
          <label :if={@resolved_label} class="block text-sm font-medium mb-1">
            {@resolved_label}
          </label>
          <.dynamic_component module={@ui_adapter} function={:select} {assigns} />
        </div>
        """

      :boolean ->
        assigns =
          assigns
          |> assign(:name, filter.name)
          |> assign(:value, "true")
          |> assign(:checked, to_boolean(assigns.value) == true)
          |> assign(
            :label,
            (filter.ui && filter.ui.label) || Phoenix.Naming.humanize(filter.name)
          )
          |> assign(:icon, filter.ui && filter.ui.icon)

        ~H"""
        <div>
          <.dynamic_component module={@ui_adapter} function={:checkbox} {assigns} />
        </div>
        """

      :relation ->
        base_map = if is_struct(filter), do: Map.from_struct(filter), else: filter
        filter_map = Map.put(base_map, :myself, assigns.myself)
        label = resolve_ui_label(filter)
        assigns = assign(assigns, :filter_map, filter_map) |> assign(:resolved_label, label)

        ~H"""
        <div>
          <label :if={@resolved_label} class="block text-sm font-medium mb-1">
            {@resolved_label}
          </label>
          {MishkaGervaz.Table.Types.Filter.Relation.render_input(@filter_map, @value, @ui_adapter)}
        </div>
        """

      :date_range ->
        base_map = if is_struct(filter), do: Map.from_struct(filter), else: filter
        label = resolve_ui_label(filter)
        assigns = assign(assigns, :filter_map, base_map) |> assign(:resolved_label, label)

        ~H"""
        <div>
          <label :if={@resolved_label} class="block text-sm font-medium mb-1">
            {@resolved_label}
          </label>
          {MishkaGervaz.Table.Types.Filter.DateRange.render_input(@filter_map, @value, @ui_adapter)}
        </div>
        """

      _ ->
        assigns =
          assigns
          |> assign(:name, filter.name)
          |> assign(:value, assigns.value || "")
          |> assign(:placeholder, (filter.ui && filter.ui.placeholder) || "")
          |> assign(:icon, filter.ui && filter.ui.icon)

        ~H"""
        <div>
          <.dynamic_component module={@ui_adapter} function={:text_input} {assigns} />
        </div>
        """
    end
  end

  @spec merge_relation_filter_state(list(), map()) :: list()
  defp merge_relation_filter_state(filters, relation_state) when is_list(filters) do
    Enum.map(filters, fn filter ->
      case Map.get(relation_state, filter.name) do
        nil ->
          filter

        dynamic_opts when is_map(dynamic_opts) ->
          filter
          |> Map.put(:options, dynamic_opts[:options] || filter.options || [])
          |> Map.put(:has_more?, dynamic_opts[:has_more?] || false)
          |> Map.put(:loading?, dynamic_opts[:loading?] || false)
          |> Map.put(:selected_options, dynamic_opts[:selected_options] || [])
          |> Map.put(:dropdown_open?, dynamic_opts[:dropdown_open?] || false)
      end
    end)
  end

  defp merge_relation_filter_state(filters, _), do: filters

  def render_bulk_actions(assigns) do
    static = assigns.static
    state = assigns.state

    selected_count = MapSet.size(state.selected_ids)
    excluded_count = MapSet.size(state.excluded_ids)
    has_selection = state.select_all? or selected_count > 0

    visible_bulk_actions =
      filter_visible_bulk_actions(static.bulk_actions, state.archive_status, state)

    assigns =
      assigns
      |> assign(:bulk_actions, static.bulk_actions)
      |> assign(:selected_ids, state.selected_ids)
      |> assign(:excluded_ids, state.excluded_ids)
      |> assign(:select_all, state.select_all?)
      |> assign(:archive_status, state.archive_status)
      |> assign(:has_selection, has_selection)
      |> assign(:excluded_count, excluded_count)
      |> assign(:selected_count, selected_count)
      |> assign(:visible_bulk_actions, visible_bulk_actions)
      |> assign(:ui_adapter, static.ui_adapter)

    ~H"""
    <.dynamic_component
      :if={@bulk_actions != [] and @has_selection and @visible_bulk_actions != []}
      module={@ui_adapter}
      function={:bulk_action_bar}
      select_all={@select_all}
      selected_count={@selected_count}
      excluded_count={@excluded_count}
      myself={@myself}
      all_selected_label={dgettext("mishka_gervaz", "All selected")}
      all_except_label={
        dgettext("mishka_gervaz", "All except %{count} selected", count: @excluded_count)
      }
      selected_label={dgettext("mishka_gervaz", "%{count} selected", count: @selected_count)}
      clear_label={dgettext("mishka_gervaz", "Clear selection")}
    >
      <.dynamic_component
        :for={action <- @visible_bulk_actions}
        module={@ui_adapter}
        function={:bulk_action_button}
        action={action}
        myself={@myself}
      />
    </.dynamic_component>
    """
  end

  defp filter_visible_bulk_actions(bulk_actions, archive_status, state) do
    Enum.filter(bulk_actions, fn action ->
      bulk_action_visible?(action, archive_status, state)
    end)
  end

  @doc """
  Check if any bulk actions are visible for the given archive status.

  Returns true if there is at least one bulk action that should be shown
  for the current mode (active or archived).
  """
  @spec has_visible_bulk_actions?(list() | term(), atom()) :: boolean()
  def has_visible_bulk_actions?(bulk_actions, archive_status) when is_list(bulk_actions) do
    Enum.any?(bulk_actions, fn action ->
      bulk_action_visible_for_status?(action, archive_status)
    end)
  end

  def has_visible_bulk_actions?(_, _), do: false

  defp bulk_action_visible_for_status?(%{visible: :active}, :active), do: true
  defp bulk_action_visible_for_status?(%{visible: :active}, _status), do: false
  defp bulk_action_visible_for_status?(%{visible: :archived}, :archived), do: true
  defp bulk_action_visible_for_status?(%{visible: :archived}, _status), do: false
  defp bulk_action_visible_for_status?(%{visible: nil}, _status), do: true

  defp bulk_action_visible_for_status?(%{visible: visible}, _status) when is_function(visible, 1),
    do: true

  defp bulk_action_visible_for_status?(_, _status), do: true

  defp bulk_action_visible?(%{restricted: true}, _archive_status, %{master_user?: false}),
    do: false

  defp bulk_action_visible?(%{visible: visible}, _archive_status, state)
       when is_function(visible, 1) do
    visible.(state)
  end

  defp bulk_action_visible?(%{visible: :active}, :active, _state), do: true
  defp bulk_action_visible?(%{visible: :active}, _status, _state), do: false
  defp bulk_action_visible?(%{visible: :archived}, :archived, _state), do: true
  defp bulk_action_visible?(%{visible: :archived}, _status, _state), do: false
  defp bulk_action_visible?(%{visible: nil}, _status, _state), do: true
  defp bulk_action_visible?(_, _status, _state), do: true

  def render_template_switcher(assigns) do
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.Table.UIAdapters.Tailwind
    assigns = assign(assigns, :ui_adapter, ui_adapter)

    ~H"""
    <.dynamic_component
      module={@ui_adapter}
      function={:template_switcher}
      switchable_templates={@switchable_templates}
      current_template={@current_template}
      myself={@myself}
    />
    """
  end

  def render_pagination(assigns) do
    static = assigns.static
    state = assigns.state
    pagination_ui = static.pagination_ui

    assigns =
      assigns
      |> assign(:page, state.page)
      |> assign(:has_more?, state.has_more?)
      |> assign(:total_pages, state.total_pages)
      |> assign(:total_count, state.total_count)
      |> assign(:page_size, static.page_size)
      |> assign(:loading, state.loading)
      |> assign(:loading_type, state.loading_type)
      |> assign(:ui_adapter, static.ui_adapter)
      |> assign(:loading_text, pagination_ui.loading_text || "Loading...")
      |> assign(:load_more_label, pagination_ui.load_more_label || "Load More")
      |> assign(:show_total, pagination_ui.show_total)
      |> assign(:prev_label, pagination_ui.prev_label || "Previous")
      |> assign(:next_label, pagination_ui.next_label || "Next")
      |> assign(:first_label, pagination_ui.first_label || "First")
      |> assign(:last_label, pagination_ui.last_label || "Last")
      |> assign(:page_info_format, pagination_ui.page_info_format || "Page {page} of {total}")

    ~H"""
    <%!-- Loading indicator for "load more" --%>
    <div
      :if={@loading == :loading and @loading_type == :more}
      class="mt-4 py-4 text-center border-t border-gray-200"
    >
      <.dynamic_component
        module={@ui_adapter}
        function={:loading_state}
        type={:more}
        style={:spinner}
        text={@loading_text}
        class="inline-flex items-center gap-2 text-gray-500"
      />
    </div>

    <%!-- Load more button --%>
    <div
      :if={@pagination_type in [:infinite, :load_more] and @has_more? and @loading != :loading}
      class="mt-4 text-center"
    >
      <.dynamic_component
        module={@ui_adapter}
        function={:pagination_nav_button}
        label={@load_more_label}
        event="load_more"
        myself={@myself}
        disabled={false}
        class="px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded transition-colors"
      />
    </div>

    <%!-- Numbered pagination --%>
    <.render_numbered_pagination
      :if={@pagination_type == :numbered and @total_pages}
      page={@page}
      total_pages={@total_pages}
      total_count={@total_count}
      page_size={@page_size}
      loading={@loading}
      ui_adapter={@ui_adapter}
      show_total={@show_total}
      prev_label={@prev_label}
      next_label={@next_label}
      first_label={@first_label}
      last_label={@last_label}
      page_info_format={@page_info_format}
      myself={@myself}
    />

    <%!-- Fallback simple numbered pagination when total_pages is not available yet --%>
    <.dynamic_component
      :if={@pagination_type == :numbered and is_nil(@total_pages)}
      module={@ui_adapter}
      function={:pagination_container}
      page={@page}
      total_pages={nil}
      total_count={@total_count}
      show_total={@show_total}
      page_info_format={@page_info_format}
    >
      <.dynamic_component
        :if={@page > 1}
        module={@ui_adapter}
        function={:pagination_nav_button}
        label={@prev_label}
        event="prev_page"
        myself={@myself}
        disabled={false}
      />
      <span class="px-3 py-1">{format_page_info(@page_info_format, @page, nil, @total_count)}</span>
      <.dynamic_component
        :if={@has_more?}
        module={@ui_adapter}
        function={:pagination_nav_button}
        label={@next_label}
        event="next_page"
        myself={@myself}
        disabled={false}
      />
    </.dynamic_component>
    """
  end

  defp render_numbered_pagination(assigns) do
    if assigns.ui_adapter && function_exported?(assigns.ui_adapter, :pagination, 1) do
      assigns =
        assigns
        |> assign(:pagination_total, assigns.total_pages)
        |> assign(:pagination_active, assigns.page)
        |> assign(:pagination_siblings, 1)
        |> assign(:pagination_boundaries, 1)
        |> assign(:pagination_on_change, "go_to_page")
        |> assign(:pagination_phx_target, assigns.myself)

      ~H"""
      <div class="mt-4 flex items-center justify-between">
        <div :if={@show_total} class="text-sm text-gray-600">
          {format_page_info(@page_info_format, @page, @total_pages, @total_count)}
        </div>
        <.dynamic_component
          module={@ui_adapter}
          function={:pagination}
          total={@pagination_total}
          active={@pagination_active}
          siblings={@pagination_siblings}
          boundaries={@pagination_boundaries}
          on_page_change={@pagination_on_change}
          phx_target={@pagination_phx_target}
        />
      </div>
      """
    else
      ~H"""
      <.dynamic_component
        module={@ui_adapter}
        function={:pagination_container}
        page={@page}
        total_pages={@total_pages}
        total_count={@total_count}
        show_total={@show_total}
        page_info_format={@page_info_format}
      >
        <%!-- First button --%>
        <.dynamic_component
          :if={@total_pages > 5 and @page > 2}
          module={@ui_adapter}
          function={:pagination_nav_button}
          label={@first_label}
          event="go_to_page"
          page={1}
          myself={@myself}
          disabled={@loading == :loading}
        />

        <%!-- Previous button --%>
        <.dynamic_component
          module={@ui_adapter}
          function={:pagination_nav_button}
          label={@prev_label}
          event="prev_page"
          myself={@myself}
          disabled={@page <= 1 or @loading == :loading}
        />

        <%!-- Page numbers --%>
        <.render_page_numbers
          page={@page}
          total_pages={@total_pages}
          myself={@myself}
          loading={@loading}
          ui_adapter={@ui_adapter}
        />

        <%!-- Next button --%>
        <.dynamic_component
          module={@ui_adapter}
          function={:pagination_nav_button}
          label={@next_label}
          event="next_page"
          myself={@myself}
          disabled={@page >= @total_pages or @loading == :loading}
        />

        <%!-- Last button --%>
        <.dynamic_component
          :if={@total_pages > 5 and @page < @total_pages - 1}
          module={@ui_adapter}
          function={:pagination_nav_button}
          label={@last_label}
          event="go_to_page"
          page={@total_pages}
          myself={@myself}
          disabled={@loading == :loading}
        />
      </.dynamic_component>
      """
    end
  end

  defp render_page_numbers(assigns) do
    page = assigns.page
    total_pages = assigns.total_pages

    pages = calculate_visible_pages(page, total_pages)

    assigns = assign(assigns, :pages, pages)

    ~H"""
    <%= for item <- @pages do %>
      <%= case item do %>
        <% :ellipsis -> %>
          <span class="px-2 py-1 text-gray-500">...</span>
        <% page_num -> %>
          <.dynamic_component
            module={@ui_adapter}
            function={:pagination_page_button}
            page_num={page_num}
            current_page={@page}
            myself={@myself}
            disabled={@loading == :loading}
          />
      <% end %>
    <% end %>
    """
  end

  defp calculate_visible_pages(_current, total) when total <= 7 do
    Enum.to_list(1..total)
  end

  defp calculate_visible_pages(current, total) do
    cond do
      current <= 3 ->
        Enum.to_list(1..5) ++ [:ellipsis, total]

      current >= total - 2 ->
        [1, :ellipsis] ++ Enum.to_list((total - 4)..total)

      true ->
        [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total]
    end
  end

  defp format_page_info(format, page, total_pages, total_count) do
    format
    |> String.replace("{page}", to_string(page))
    |> String.replace("{total}", to_string(total_pages || "?"))
    |> String.replace("{count}", to_string(total_count || ""))
  end

  def render_row_actions(assigns) do
    layout = assigns.static.row_actions_layout
    dropdowns = assigns.static.row_action_dropdowns

    has_layout? = layout != nil and (dropdowns != [] or layout[:inline] != [])

    assigns =
      assigns
      |> Phoenix.Component.assign(:has_layout?, has_layout?)
      |> Phoenix.Component.assign(:layout, layout)
      |> Phoenix.Component.assign(:dropdowns, dropdowns || [])

    ~H"""
    <div class="flex gap-2">
      <%= if @has_layout? do %>
        <.render_inline_actions
          :if={@layout[:inline] != []}
          inline_names={@layout[:inline] || []}
          row_actions={@row_actions}
          record={@record}
          static={@static}
          state={@state}
          myself={@myself}
        />
        <.render_dropdown_menu
          :for={dropdown <- @dropdowns}
          :if={dropdown.name in (@layout[:dropdown] || [])}
          dropdown={dropdown}
          record={@record}
          static={@static}
          state={@state}
          myself={@myself}
        />
      <% else %>
        <.render_action
          :for={action <- @row_actions}
          :if={
            action_visible?(action, @record, @state) and action_authorized?(action, @record, @state)
          }
          action={action}
          record={@record}
          state={@state}
          static={@static}
          ui_adapter={@static.ui_adapter}
          myself={@myself}
        />
      <% end %>
    </div>
    """
  end

  defp render_inline_actions(assigns) do
    inline_names = assigns.inline_names

    visible_inline =
      assigns.row_actions
      |> Enum.filter(fn action ->
        action[:name] in inline_names and
          action_visible?(action, assigns.record, assigns.state) and
          action_authorized?(action, assigns.record, assigns.state)
      end)

    assigns = Phoenix.Component.assign(assigns, :visible_inline, visible_inline)

    ~H"""
    <.render_action
      :for={action <- @visible_inline}
      action={action}
      record={@record}
      state={@state}
      static={@static}
      ui_adapter={@static.ui_adapter}
      myself={@myself}
    />
    """
  end

  defp render_dropdown_menu(assigns) do
    visible_items =
      Enum.filter(assigns.dropdown.items, fn
        %{type: :separator} ->
          true

        action ->
          action_visible?(action, assigns.record, assigns.state) and
            action_authorized?(action, assigns.record, assigns.state)
      end)

    has_visible? = Enum.any?(visible_items, fn item -> item[:type] != :separator end)
    total = length(visible_items)

    dropdown_ui = assigns.dropdown[:ui] || %{}
    icon = dropdown_ui[:icon] || "hero-ellipsis-vertical"

    assigns =
      assigns
      |> Phoenix.Component.assign(:visible_items, visible_items)
      |> Phoenix.Component.assign(:has_visible?, has_visible?)
      |> Phoenix.Component.assign(:total, total)
      |> Phoenix.Component.assign(:icon, icon)

    ~H"""
    <div :if={@has_visible?}>
      <.dynamic_component module={@static.ui_adapter} function={:dropdown} icon={@icon}>
        <.render_dropdown_item
          :for={{item, idx} <- Enum.with_index(@visible_items)}
          :if={item[:type] != :separator or render_separator?(@visible_items, @total, idx)}
          item={item}
          record={@record}
          static={@static}
          state={@state}
          myself={@myself}
        />
      </.dynamic_component>
    </div>
    """
  end

  defp render_dropdown_item(%{item: %{type: :separator}} = assigns) do
    ~H"""
    <div class="border-t border-gray-100 my-1">
      <div :if={@item[:label]} class="px-3 py-1 text-xs font-semibold text-gray-400 uppercase">
        {@item[:label]}
      </div>
    </div>
    """
  end

  defp render_dropdown_item(assigns) do
    ~H"""
    <.render_action
      action={@item}
      record={@record}
      state={@state}
      static={@static}
      ui_adapter={@static.ui_adapter}
      myself={@myself}
    />
    """
  end

  defp render_action(assigns) do
    action = assigns.action

    case Map.get(action, :render) do
      render_fn when is_function(render_fn, 1) ->
        render_fn.(assigns.record)

      render_fn when is_function(render_fn, 2) ->
        render_fn.(assigns.record, action)

      render_fn when is_function(render_fn, 3) ->
        render_fn.(assigns.record, action, assigns.myself)

      _ ->
        type_module = action[:type_module] || MishkaGervaz.Table.Types.Action.Event
        type_module.render(assigns, action, assigns.record, assigns.ui_adapter, assigns.myself)
    end
  end

  defp render_separator?(items, total, index) do
    index > 0 and index < total - 1 and
      not match?(%{type: :separator}, Enum.at(items, index - 1))
  end

  @doc """
  Checks if a row action is visible for a given record and state.

  Used by templates to filter visible row actions.
  """
  def action_visible?(%{visible: visible}, record, state) when is_function(visible, 2) do
    visible.(record, state)
  end

  def action_visible?(%{visible: :active}, _record, %{archive_status: :active}), do: true
  def action_visible?(%{visible: :active}, _record, _state), do: false
  def action_visible?(%{visible: :archived}, _record, %{archive_status: :archived}), do: true
  def action_visible?(%{visible: :archived}, _record, _state), do: false
  def action_visible?(%{visible: false}, _record, _state), do: false
  def action_visible?(_, _record, _state), do: true

  defp action_authorized?(%{restricted: true}, record, state) do
    MishkaGervaz.Table.Web.State.can_modify_record?(state, record)
  end

  defp action_authorized?(_, _record, _state), do: true

  @doc """
  Renders the empty state with configurable message, icon, and action.
  """
  @spec render_empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def render_empty_state(assigns) do
    empty_state = assigns[:empty_state] || %{}
    action = Map.get(empty_state, :action) || %{}
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.Table.UIAdapters.Tailwind

    assigns =
      assigns
      |> assign(
        :message,
        Map.get(empty_state, :message, dgettext("mishka_gervaz", "No records found"))
      )
      |> assign(:icon, Map.get(empty_state, :icon, "hero-inbox"))
      |> assign(:action_label, Map.get(action, :label))
      |> assign(:action_path, Map.get(action, :path))
      |> assign(:action_icon, Map.get(action, :icon))
      |> assign(:ui_adapter, ui_adapter)

    ~H"""
    <.dynamic_component
      module={@ui_adapter}
      function={:empty_state}
      message={@message}
      icon={@icon}
      action_label={@action_label}
      action_path={@action_path}
      action_icon={@action_icon}
    />
    """
  end

  @doc """
  Renders the error state with configurable message, icon, and retry button.
  """
  @spec render_error_state(map()) :: Phoenix.LiveView.Rendered.t()
  def render_error_state(assigns) do
    error_state = assigns[:error_state] || %{}
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.Table.UIAdapters.Tailwind

    assigns =
      assigns
      |> assign(
        :message,
        Map.get(error_state, :message, dgettext("mishka_gervaz", "Error loading data"))
      )
      |> assign(:icon, Map.get(error_state, :icon))
      |> assign(
        :retry_label,
        Map.get(error_state, :retry_label, dgettext("mishka_gervaz", "Retry"))
      )
      |> assign(:ui_adapter, ui_adapter)

    ~H"""
    <.dynamic_component
      module={@ui_adapter}
      function={:error_state}
      message={@message}
      icon={@icon}
      retry_label={@retry_label}
      target={@myself}
    />
    """
  end

  @doc """
  Renders the loading state with spinner and configurable text.
  """
  @spec render_loading(map()) :: Phoenix.LiveView.Rendered.t()
  def render_loading(assigns) do
    loading_text = assigns[:loading_text] || dgettext("mishka_gervaz", "Loading...")
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.Table.UIAdapters.Tailwind
    loading_style = assigns[:loading_style] || :spinner

    assigns =
      assigns
      |> assign(:loading_text, loading_text)
      |> assign(:ui_adapter, ui_adapter)
      |> assign(:loading_style, loading_style)

    ~H"""
    <.dynamic_component
      module={@ui_adapter}
      function={:loading_state}
      type={:initial}
      style={@loading_style}
      text={@loading_text}
    />
    """
  end

  def render_cell(assigns) do
    {column, record, static, state} =
      {assigns.column, assigns.record, assigns[:static], assigns[:state]}

    ui = (static && static.ui_adapter) || MishkaGervaz.Table.UIAdapters.Tailwind
    value = MishkaGervaz.Table.Behaviours.Template.get_cell_value(record, column)
    formatted_value = apply_format(Map.get(column, :format), state, record, value)
    render_input = build_render_input(column, record, formatted_value, state)

    assigns = assign(assigns, :value, formatted_value)

    cond do
      column.render && is_function(column.render, 1) ->
        assigns = assign(assigns, :rendered, column.render.(render_input))
        ~H"{@rendered}"

      column.render && is_function(column.render, 2) ->
        assigns = assign(assigns, :rendered, column.render.(render_input, state))
        ~H"{@rendered}"

      column.type_module ->
        column.type_module.render(formatted_value, column, record, ui)

      true ->
        ~H"{@value}"
    end
  end

  @spec build_render_input(map(), struct(), any(), map() | nil) :: map() | any()
  defp build_render_input(%{static: true, requires: requires}, record, _formatted_value, _state)
       when requires != [] do
    Map.new(requires, fn field -> {field, Map.get(record, field)} end)
  end

  defp build_render_input(_column, _record, formatted_value, _state), do: formatted_value

  defp apply_format(nil, _state, _record, value), do: value

  defp apply_format(format, _state, _record, value) when is_function(format, 1),
    do: format.(value)

  defp apply_format(format, state, record, value) when is_function(format, 3),
    do: format.(state, record, value)

  defp apply_format(_format, _state, _record, value), do: value
end
