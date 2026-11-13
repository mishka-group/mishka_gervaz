defmodule MishkaGervaz.Table.Templates.Shared do
  @moduledoc """
  Shared rendering functions used by all templates.

  These provide default implementations for common UI elements like
  filters, bulk actions, pagination, and template switcher.

  ## Assigns

  All functions expect two key assigns:
  - `@static` - Same reference always (columns, filters, ui_adapter, etc.)
  - `@state` - Changes trigger re-render (page, filter_values, etc.)

  See `MishkaGervaz.Table.Behaviours.Template`,
  `MishkaGervaz.Table.Templates.Table`,
  `MishkaGervaz.Table.Templates.MediaGallery`, and
  `MishkaGervaz.Table.Web.Renderer`.
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
      find_by_name: 2,
      resolve_label: 1,
      translate_options: 1,
      translate_text: 1
    ]

  @doc """
  Unchecks all selection checkboxes and removes selection highlighting.
  """
  @spec uncheck_all(JS.t(), String.t() | nil) :: JS.t()
  def uncheck_all(js \\ %JS{}, scope \\ nil) do
    prefix = scope_prefix(scope)

    js
    |> JS.remove_attribute("checked", to: prefix <> ".gervaz-row-checkbox")
    |> JS.remove_attribute("checked", to: prefix <> ".gervaz-media-checkbox")
    |> JS.remove_attribute("checked", to: prefix <> ".gervaz-select-all-checkbox")
    |> JS.remove_class("bg-accent", to: prefix <> ".gervaz-row")
  end

  @doc """
  Checks all table row checkboxes and adds selection highlighting.
  """
  @spec check_all_table(JS.t(), String.t() | nil) :: JS.t()
  def check_all_table(js \\ %JS{}, scope \\ nil) do
    prefix = scope_prefix(scope)

    js
    |> JS.set_attribute({"checked", "checked"}, to: prefix <> ".gervaz-row-checkbox")
    |> JS.add_class("bg-accent", to: prefix <> ".gervaz-row")
  end

  @doc """
  Checks all media gallery checkboxes.
  """
  @spec check_all_gallery(JS.t(), String.t() | nil) :: JS.t()
  def check_all_gallery(js \\ %JS{}, scope \\ nil) do
    prefix = scope_prefix(scope)

    js
    |> JS.set_attribute({"checked", "checked"}, to: prefix <> ".gervaz-media-checkbox")
    |> JS.set_attribute({"checked", "checked"}, to: prefix <> ".gervaz-select-all-checkbox")
  end

  defp scope_prefix(nil), do: ""
  defp scope_prefix(scope), do: "##{scope} "

  @doc """
  Renders the filter bar: the toolbar row, any collapsible filter groups, the active-filter
  chips and the archive toggle.

  The default `render_filters/1` of every template built with
  `use MishkaGervaz.Table.Behaviours.Template`. Call it from a custom template rather than
  rebuilding the bar.

      def render_filters(assigns), do: Shared.render_filters(assigns)

  Expects `@static` and `@state`.
  """
  def render_filters(assigns) do
    static = assigns.static
    state = assigns.state

    all_filters = merge_relation_filter_state(static.filters, state.relation_filter_state || %{})
    filters = Enum.filter(all_filters, &accessible?(&1, state))
    groups = static.filter_groups || []
    has_groups = groups != []
    filter_mode = static.filter_mode || :inline

    assigns =
      assigns
      |> assign(:filters, filters)
      |> assign(:all_filters, all_filters)
      |> assign(:has_active_filters, map_size(state.filter_values) > 0)
      |> assign(:filter_mode, filter_mode)
      |> assign(:groups, groups)
      |> assign(:has_groups, has_groups)
      |> assign_new(:filter_actions, fn -> nil end)

    ~H"""
    <div :if={@filters != [] or @state.supports_archive} class="mb-4">
      <%= if @has_groups do %>
        <.render_grouped_filters
          filters={@filters}
          all_filters={@all_filters}
          has_active_filters={@has_active_filters}
          filter_actions={@filter_actions}
          groups={@groups}
          columns={4}
          state={@state}
          static={@static}
          myself={@myself}
        />
      <% else %>
        <.render_filters_by_mode
          mode={@filter_mode}
          filters={@filters}
          all_filters={@all_filters}
          has_active_filters={@has_active_filters}
          filter_actions={@filter_actions}
          columns={4}
          collapsible={true}
          collapsed={false}
          groups={[]}
          state={@state}
          static={@static}
          myself={@myself}
        />
      <% end %>
    </div>
    """
  end

  @toolbar_field "h-[42px] w-full rounded-xl border border-[#ecebe6] bg-white ps-10 pe-3.5 " <>
                   "text-[13px] font-medium text-[#1b1a18] outline-none transition-colors " <>
                   "focus:border-[#c3c1f0]"

  @toolbar_toggle "order-4 inline-flex h-[42px] flex-none items-center gap-[7px] rounded-xl " <>
                    "border border-[#ecebe6] bg-white px-[15px] text-[12.5px] font-semibold " <>
                    "text-[#5c5a54] transition-colors"

  @toolbar_panel "order-6 hidden basis-full rounded-[14px] border border-[#e4e2f7] bg-white " <>
                   "px-[18px] py-4 [&_label]:mb-[9px]! [&_label]:text-[10px]! " <>
                   "[&_label]:font-bold! [&_label]:uppercase [&_label]:tracking-[0.07em] " <>
                   "[&_label]:text-[#8a877f]"

  defp render_grouped_filters(assigns) do
    groups = assigns.groups
    all_filter_names = assigns.filters |> Enum.map(& &1.name)

    grouped_filter_names =
      groups |> Enum.flat_map(fn g -> g.filters end) |> MapSet.new()

    ungrouped_filters =
      Enum.filter(assigns.filters, fn f -> not MapSet.member?(grouped_filter_names, f.name) end)

    visible_groups =
      groups
      |> Enum.filter(fn group ->
        accessible_group?(group, assigns.state) and
          Enum.any?(group.filters, fn name -> name in all_filter_names end)
      end)
      |> sort_by_position()

    assigns =
      assigns
      |> assign(:visible_groups, visible_groups)
      |> assign(:ungrouped_filters, ungrouped_filters)
      |> assign_new(:filter_actions, fn -> nil end)

    ~H"""
    <div data-role="gz-toolbar" class="flex flex-wrap items-center gap-3">
      <div
        :if={@filter_actions not in [nil, []]}
        class="order-1 flex flex-none items-center gap-2 max-[860px]:order-2!"
      >
        {render_slot(@filter_actions)}
      </div>

      <div :if={@state.supports_archive} class="order-3">
        <.dynamic_component
          module={@static.ui_adapter}
          function={:archive_toggle}
          table_id={@static.id}
          archive_status={@state.archive_status}
          myself={@myself}
        />
      </div>

      <form
        id={"#{@static.stream_name}-filter"}
        phx-change="filter"
        phx-target={@myself}
        class="contents"
      >
        <.render_toolbar_filter
          :for={filter <- @ungrouped_filters}
          filter={filter}
          all_filters={@all_filters}
          state={@state}
          static={@static}
          myself={@myself}
        />

        <.render_filter_group
          :for={group <- @visible_groups}
          group={group}
          filters={@filters}
          all_filters={@all_filters}
          columns={@columns}
          has_active_filters={@has_active_filters}
          state={@state}
          static={@static}
          myself={@myself}
        />
      </form>
    </div>
    """
  end

  defp render_toolbar_filter(%{filter: %{type: :text}} = assigns) do
    assigns = assign(assigns, :field_class, @toolbar_field)

    ~H"""
    <div class="relative order-2 min-w-[210px] flex-1 max-[860px]:order-1! max-[860px]:basis-full!">
      <.dynamic_component
        module={@static.ui_adapter}
        function={:icon}
        name="hero-magnifying-glass"
        class="pointer-events-none absolute start-[14px] top-1/2 size-4 -translate-y-1/2 text-[#a8a5a0]"
      />
      <input
        type="text"
        id={filter_input_id(@static, @filter)}
        name={@filter.name}
        value={Map.get(@state.filter_values, @filter.name) || ""}
        placeholder={search_placeholder(@filter)}
        aria-label={filter_label(@filter)}
        phx-debounce="300"
        class={[@field_class, "[unicode-bidi:plaintext]"]}
      />
    </div>
    """
  end

  defp render_toolbar_filter(assigns) do
    ~H"""
    <div class="order-2 min-w-0 flex-none [&_label]:sr-only">
      <.render_filter
        filter={@filter}
        all_filters={@all_filters}
        state={@state}
        static={@static}
        myself={@myself}
      />
    </div>
    """
  end

  defp render_filter_group(assigns) do
    group = assigns.group
    group_filters = Enum.filter(assigns.filters, fn f -> f.name in group.filters end)

    assigns =
      assigns
      |> assign(:group_filters, group_filters)
      |> assign(:group_columns, (group.ui && group.ui.columns) || 3)
      |> assign(:group_label, group_label(group))
      |> assign(:group_icon, (group.ui && group.ui.icon) || "hero-adjustments-horizontal")
      |> assign(:group_id, "#{assigns.static.id}-filter-group-#{group.name}")
      |> assign(:toggle_class, @toolbar_toggle)
      |> assign(:panel_class, @toolbar_panel)

    ~H"""
    <%= if @group.collapsible do %>
      <button
        :if={@group_filters != []}
        type="button"
        id={"#{@group_id}-btn"}
        phx-click={toggle_filter_group(@group_id)}
        aria-controls={@group_id}
        class={@toggle_class}
      >
        <.dynamic_component
          module={@static.ui_adapter}
          function={:icon}
          name={@group_icon}
          class="size-[15px]"
        />
        {@group_label}
      </button>

      <div
        :if={@group_filters != []}
        id={@group_id}
        class={[@panel_class, !@group.collapsed && "block!"]}
      >
        <div class={[
          "grid gap-3 [&>*]:min-w-0",
          grid_cols(@group_columns),
          "max-[860px]:grid-cols-2! max-[640px]:grid-cols-1!"
        ]}>
          <.render_filter
            :for={filter <- @group_filters}
            filter={filter}
            all_filters={@all_filters}
            state={@state}
            static={@static}
            myself={@myself}
          />
        </div>

        <button
          :if={@has_active_filters}
          type="button"
          phx-click="clear_filters"
          phx-target={@myself}
          class="mt-4 inline-flex h-[30px] items-center gap-1.5 rounded-lg border border-[#ecebe6] bg-white px-[11px] text-[11.5px] font-semibold text-[#5c5a54] transition-colors hover:bg-[#f7f6f3]"
        >
          <.dynamic_component
            module={@static.ui_adapter}
            function={:icon}
            name="hero-x-mark"
            class="size-[13px] text-[#a8a5a0]"
          />
          {dgettext("mishka_gervaz", "Clear filters")}
        </button>
      </div>
    <% else %>
      <.render_toolbar_filter
        :for={filter <- @group_filters}
        filter={filter}
        all_filters={@all_filters}
        state={@state}
        static={@static}
        myself={@myself}
      />
    <% end %>
    """
  end

  defp toggle_filter_group(group_id) do
    JS.toggle(to: "##{group_id}")
    |> JS.toggle_class("border-[#ecebe6] bg-white text-[#5c5a54]", to: "##{group_id}-btn")
    |> JS.toggle_class("border-[#dcdbf5] bg-[#f2f1fc] text-[#4f4bcc]", to: "##{group_id}-btn")
  end

  defp search_placeholder(filter) do
    resolve_label(filter.ui && filter.ui.placeholder) || dgettext("mishka_gervaz", "Search…")
  end

  @doc """
  Checks if a filter group is visible and accessible for the current state.
  """
  def accessible_group?(group, state) do
    visible =
      case group.visible do
        fun when is_function(fun, 1) -> fun.(state)
        val -> val
      end

    restricted =
      case group.restricted do
        fun when is_function(fun, 1) -> fun.(state)
        val -> val
      end

    visible and (not restricted or Map.get(state, :master_user?, false))
  end

  @doc """
  Sorts filter groups by their position attribute.
  """
  def sort_by_position(groups) do
    Enum.sort_by(groups, fn group ->
      case group.position do
        :first -> {0, 0}
        :last -> {2, 0}
        n when is_integer(n) -> {1, n}
        _ -> {1, 999}
      end
    end)
  end

  defp render_filters_by_mode(%{mode: :inline} = assigns) do
    input_filters = Enum.reject(assigns.filters, &(&1.type == :boolean))
    bool_filters = Enum.filter(assigns.filters, &(&1.type == :boolean))
    total = assigns.state.total_count

    range_label =
      if is_integer(total),
        do: dgettext("mishka_gervaz", "Showing %{count}", count: total)

    assigns =
      assigns
      |> assign(:input_filters, input_filters)
      |> assign(:bool_filters, bool_filters)
      |> assign(:range_label, range_label)
      |> assign_new(:filter_actions, fn -> nil end)

    show_controls =
      assigns.state.supports_archive or bool_filters != [] or assigns.has_active_filters or
        range_label != nil or assigns[:filter_actions] not in [nil, []]

    assigns = assign(assigns, :show_controls, show_controls)

    ~H"""
    <form
      :if={@filters != [] or @state.supports_archive}
      id={"#{@static.stream_name}-filter"}
      phx-change="filter"
      phx-target={@myself}
      class="space-y-[16px]"
    >
      <div
        :if={@input_filters != []}
        class="flex flex-wrap items-end gap-[14px]"
      >
        <.render_filter
          :for={filter <- @input_filters}
          filter={filter}
          all_filters={@all_filters}
          state={@state}
          static={@static}
          myself={@myself}
        />
      </div>

      <div :if={@show_controls} class="flex flex-wrap items-center gap-[14px]">
        <.dynamic_component
          :if={@state.supports_archive}
          module={@static.ui_adapter}
          function={:archive_toggle}
          table_id={@static.id}
          archive_status={@state.archive_status}
          myself={@myself}
        />
        <.render_filter
          :for={filter <- @bool_filters}
          filter={filter}
          all_filters={@all_filters}
          state={@state}
          static={@static}
          myself={@myself}
        />
        <span class="flex-1"></span>
        <span
          :if={@range_label}
          id={"#{@static.id}-total"}
          class="text-[12px] font-medium text-[#a8a5a0]"
        >
          {@range_label}
        </span>
        <.dynamic_component
          :if={@has_active_filters}
          module={@static.ui_adapter}
          function={:filter_reset_button}
          label={dgettext("mishka_gervaz", "Clear filters")}
        />
        <%= if @filter_actions not in [nil, []] do %>
          {render_slot(@filter_actions)}
        <% end %>
      </div>
    </form>
    """
  end

  defp render_filters_by_mode(%{mode: :sidebar} = assigns) do
    ~H"""
    <div class="flex gap-4">
      <aside class="w-64 shrink-0 border-e pe-4">
        <.dynamic_component
          :if={@state.supports_archive}
          module={@static.ui_adapter}
          function={:archive_toggle}
          table_id={@static.id}
          archive_status={@state.archive_status}
          myself={@myself}
        />

        <form
          :if={@filters != []}
          id={"#{@static.stream_name}-filter"}
          phx-change="filter"
          phx-target={@myself}
          class="space-y-4 mt-4"
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
            class="mt-4 text-[12px] font-semibold text-[#8a877f] underline transition-colors hover:text-[#3a382f]"
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
        table_id={@static.id}
        archive_status={@state.archive_status}
        myself={@myself}
      />

      <.dynamic_component
        module={@static.ui_adapter}
        function={:button}
        type="button"
        label={dgettext("mishka_gervaz", "Filters")}
        icon="hero-funnel-solid"
        class="flex h-[42px] items-center gap-2 rounded-[11px] border border-[#ecebe6] bg-white px-[15px] text-[12.5px] font-semibold text-[#5c5a54] transition-colors hover:bg-[#f7f6f3]"
        phx-click="toggle_filters"
        phx-target={@myself}
      />

      <.dynamic_component
        :if={@has_active_filters}
        module={@static.ui_adapter}
        function={:button}
        type="button"
        label={dgettext("mishka_gervaz", "Clear filters")}
        class="text-[12px] font-semibold text-[#8a877f] underline transition-colors hover:text-[#3a382f]"
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
        table_id={@static.id}
        archive_status={@state.archive_status}
        myself={@myself}
      />

      <form
        :if={@filters != []}
        id={"#{@static.stream_name}-filter"}
        phx-change="filter"
        phx-target={@myself}
        class="contents"
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
        />
      </form>
    </div>
    """
  end

  @doc """
  Returns the Tailwind grid-cols class for a given column count.
  """
  def grid_cols(1), do: "grid-cols-1"
  def grid_cols(2), do: "grid-cols-2"
  def grid_cols(3), do: "grid-cols-3"
  def grid_cols(4), do: "grid-cols-4"
  def grid_cols(5), do: "grid-cols-5"
  def grid_cols(6), do: "grid-cols-6"
  def grid_cols(nil), do: "grid-cols-4"
  def grid_cols(_), do: "grid-cols-4"

  @rail_grid "grid grid-cols-[minmax(0,1fr)_300px] grid-rows-[auto_1fr] items-start gap-x-[22px] " <>
               "gap-y-4 max-[980px]:grid-cols-1! max-[980px]:grid-rows-none!"

  @rail_top "col-start-1 row-start-1 min-w-0 max-[980px]:col-start-auto! max-[980px]:row-start-auto!"

  @rail_side "col-start-2 row-start-1 row-span-2 flex flex-col gap-4 max-[980px]:col-start-auto! " <>
               "max-[980px]:row-span-1! max-[980px]:row-start-auto! max-[980px]:grid! " <>
               "max-[980px]:grid-cols-2! max-[560px]:grid-cols-1!"

  @rail_bottom "col-start-1 row-start-2 min-w-0 max-[980px]:col-start-auto! max-[980px]:row-start-auto!"

  @doc """
  The four class strings that put a page's `:rail` slot beside its records rather than above them.

  Returns `nil` for every region when the page passed no rail, and HEEx omits a `nil` attribute
  entirely, so a template can spread these across its markup unconditionally.
  """
  @spec rail_class(list() | nil, :grid | :top | :rail | :bottom) :: String.t() | nil
  def rail_class(rail, _region) when rail in [nil, []], do: nil
  def rail_class(_rail, :grid), do: @rail_grid
  def rail_class(_rail, :top), do: @rail_top
  def rail_class(_rail, :rail), do: @rail_side
  def rail_class(_rail, :bottom), do: @rail_bottom

  @doc """
  Returns the icon name for a filter group, falling back to "hero-funnel".
  Useful for custom templates rendering their own filter group UI.
  """
  @spec group_icon(map()) :: String.t()
  def group_icon(group) do
    (group.ui && group.ui.icon) || "hero-funnel"
  end

  @doc """
  Returns the resolved label for a filter group, falling back to humanized group name.
  Useful for custom templates rendering their own filter group UI.
  """
  @spec group_label(map()) :: String.t()
  def group_label(group) do
    (group.ui && resolve_ui_label(group)) || translate_text(Phoenix.Naming.humanize(group.name))
  end

  @doc """
  Returns the column count from a filter group's UI config, or nil if not set.
  Pass the result to `grid_cols/1` for the Tailwind class.
  """
  @spec group_columns(map()) :: pos_integer() | nil
  def group_columns(group) do
    group.ui && group.ui.columns
  end

  @doc """
  Returns the CSS class for a collapsible filter group panel wrapper.
  Falls back to a default rounded panel style if not set in DSL.
  """
  @spec group_panel_class(map()) :: String.t()
  def group_panel_class(group) do
    (group.ui && group.ui.class) || "rounded-[14px] border border-[#ecebe6] bg-[#faf9f6] p-4"
  end

  @doc """
  Returns the CSS class for an inline (non-collapsible) group wrapper.
  If the group has `ui do class "..." end`, uses that. Otherwise defaults to
  `"contents"` which makes the wrapper transparent so filters participate
  directly in the parent flex layout.
  """
  @spec inline_group_class(map()) :: String.t()
  def inline_group_class(group) do
    (group.ui && group.ui.class) || "contents"
  end

  @doc """
  Returns a CSS class for inline (non-collapsible) filters based on filter type.
  Text filters get a flexible width, relation filters a minimum width, others a smaller minimum.
  Only used when the group has no custom class (i.e., wrapper is `"contents"`).
  Custom templates can override this if they need different sizing.
  """
  @spec inline_filter_class(map()) :: String.t()
  def inline_filter_class(%{type: :text}), do: "flex-1 max-w-md"
  def inline_filter_class(%{type: :relation}), do: "min-w-[200px]"
  def inline_filter_class(_), do: "min-w-[160px]"

  @doc """
  One filter's input, resolved from its type — text, select, boolean, relation, date range — including
  the disabled state a `depends_on` filter wears until its parent has a value.

  Call it from a custom template that lays the filters out itself, the same way `render_cell/1` and
  `render_row_actions/1` are called.

  Expects `:filter`, `:all_filters`, `:state`, `:static` and `:myself`.
  """
  def render_filter(assigns) do
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
    do: translate_text(prompt)

  defp get_disabled_prompt(%{ui: %{disabled_prompt: prompt}}, _) when is_function(prompt, 0),
    do: prompt.()

  defp get_disabled_prompt(%{depends_on: depends_on}, all_filters) when not is_nil(depends_on) do
    parent_label =
      case find_by_name(all_filters, depends_on) do
        nil -> nil
        parent -> resolve_ui_label(parent)
      end

    field_name = parent_label || translate_text(Phoenix.Naming.humanize(depends_on))
    dgettext("mishka_gervaz", "Select %{field} first", field: field_name)
  end

  defp get_disabled_prompt(_, _), do: dgettext("mishka_gervaz", "Select parent filter first")

  defp render_disabled_filter(assigns) do
    label = resolve_ui_label(assigns.filter)

    assigns = assign(assigns, :resolved_label, label)

    ~H"""
    <div class="min-w-[170px] flex-1">
      <label
        :if={@resolved_label}
        class="mb-1.5 block text-[10.5px] font-bold text-[#a8a5a0]"
      >
        {@resolved_label}
      </label>
      <div class="h-11 cursor-not-allowed rounded-[11px] border border-[#ecebe6] bg-[#f6f5f2] px-[14px] text-[13px] font-medium text-[#8a877f]">
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
          resolve_label(filter.ui && filter.ui.placeholder) ||
            dgettext("mishka_gervaz", "Search...")

        resolved_label = filter_label(filter)

        assigns =
          assigns
          |> assign(:name, filter.name)
          |> assign(:value, assigns.value || "")
          |> assign(:placeholder, placeholder)
          |> assign(:icon, filter.ui && filter.ui.icon)
          |> assign(:search, true)
          |> assign(:resolved_label, resolved_label)
          |> assign(:id, filter_input_id(assigns.static, filter))

        ~H"""
        <div class="min-w-[240px] flex-[2]">
          <label
            :if={@resolved_label}
            class="mb-1.5 block text-[10.5px] font-bold text-[#8a877f]"
            for={@id}
          >
            {@resolved_label}
          </label>
          <.dynamic_component module={@ui_adapter} function={:text_input} {assigns} />
        </div>
        """

      :select ->
        resolved_label = filter_label(filter)

        assigns =
          assigns
          |> assign(:name, filter.name)
          |> assign(:options, translate_options(filter.options || []))
          |> assign(
            :prompt,
            translate_text(filter.ui && filter.ui.prompt) ||
              dgettext("mishka_gervaz", "Select...")
          )
          |> assign(:icon, filter.ui && filter.ui.icon)
          |> assign(:search, true)
          |> assign(:resolved_label, resolved_label)
          |> assign(:id, filter_input_id(assigns.static, filter))

        ~H"""
        <div class="min-w-[170px] flex-1">
          <label
            :if={@resolved_label}
            class="mb-1.5 block text-[10.5px] font-bold text-[#8a877f]"
            for={@id}
          >
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
          |> assign(:label, filter_label(filter))
          |> assign(:icon, filter.ui && filter.ui.icon)

        ~H"""
        <div>
          <.dynamic_component module={@ui_adapter} function={:checkbox} {assigns} />
        </div>
        """

      :relation ->
        base_map = if is_struct(filter), do: Map.from_struct(filter), else: filter

        filter_map =
          base_map
          |> Map.put(:myself, assigns.myself)
          |> Map.put(:table_id, assigns.static.id)
          |> Map.put(:input_id, filter_input_id(assigns.static, filter))

        label = resolve_ui_label(filter)
        assigns = assign(assigns, :filter_map, filter_map) |> assign(:resolved_label, label)

        ~H"""
        <div class="min-w-[170px] flex-1">
          <label
            :if={@resolved_label}
            class="mb-1.5 block text-[10.5px] font-bold text-[#8a877f]"
            for={@filter_map.input_id}
          >
            {@resolved_label}
          </label>
          {MishkaGervaz.Table.Types.Filter.Relation.render_input(@filter_map, @value, @ui_adapter)}
        </div>
        """

      :date_range ->
        base_map = if is_struct(filter), do: Map.from_struct(filter), else: filter

        assigns =
          assigns
          |> assign(:resolved_label, filter_label(filter))
          |> assign(
            :filter_map,
            Map.put(base_map, :input_id, filter_input_id(assigns.static, filter))
          )

        ~H"""
        <div
          role="group"
          aria-label={@resolved_label}
          data-role="gervaz-date-range-filter"
          class="min-w-[min(100%,310px)] max-w-[420px] flex-[1.6]"
        >
          <label class="mb-1.5 block text-[10.5px] font-bold text-[#8a877f]">
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
          |> assign(:placeholder, resolve_label(filter.ui && filter.ui.placeholder) || "")
          |> assign(:icon, filter.ui && filter.ui.icon)
          |> assign(:id, filter_input_id(assigns.static, filter))
          |> assign(:aria_label, filter_label(filter))

        ~H"""
        <div>
          <.dynamic_component module={@ui_adapter} function={:text_input} {assigns} />
        </div>
        """
    end
  end

  defp filter_label(filter),
    do: resolve_ui_label(filter) || translate_text(Phoenix.Naming.humanize(filter.name))

  defp filter_input_id(static, filter), do: "#{static.id}-filter-#{filter.name}"

  @doc """
  Merges dynamic relation filter state (options, loading, etc.) into filter configs.
  """
  @spec merge_relation_filter_state(list(), map()) :: list()
  def merge_relation_filter_state(filters, relation_state) when is_list(filters) do
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

  def merge_relation_filter_state(filters, _), do: filters

  @doc """
  Prepares all filter groups for rendering by custom templates.

  Resolves accessible filters, splits them into visible groups (sorted by position),
  and identifies ungrouped filters. Each group entry includes the resolved filter
  structs (not just names).

  Returns a map:

      %{
        all_filters: [filter_struct],
        visible_groups: [%{group | resolved_filters: [filter_struct]}],
        ungrouped_filters: [filter_struct],
        inline_groups: [group],      # non-collapsible
        collapsible_groups: [group]   # collapsible
      }
  """
  @spec prepare_filter_groups(list(), list(), map()) :: map()
  def prepare_filter_groups(filters, groups, state) do
    all_filters =
      merge_relation_filter_state(filters, state.relation_filter_state || %{})
      |> Enum.filter(&accessible?(&1, state))

    all_filter_names = Enum.map(all_filters, & &1.name)

    visible_groups =
      (groups || [])
      |> Enum.filter(fn group ->
        accessible_group?(group, state) and
          Enum.any?(group.filters, fn name -> name in all_filter_names end)
      end)
      |> sort_by_position()
      |> Enum.map(fn group ->
        resolved = Enum.filter(all_filters, fn f -> f.name in group.filters end)
        Map.put(group, :resolved_filters, resolved)
      end)

    grouped_filter_names =
      (groups || []) |> Enum.flat_map(fn g -> g.filters end) |> MapSet.new()

    ungrouped_filters =
      Enum.filter(all_filters, fn f -> not MapSet.member?(grouped_filter_names, f.name) end)

    inline_groups = Enum.filter(visible_groups, fn g -> not g.collapsible end)
    collapsible_groups = Enum.filter(visible_groups, fn g -> g.collapsible end)

    %{
      all_filters: all_filters,
      visible_groups: visible_groups,
      ungrouped_filters: ungrouped_filters,
      inline_groups: inline_groups,
      collapsible_groups: collapsible_groups
    }
  end

  @doc """
  Renders the bulk-action bar shown once rows are selected.

  Only the actions visible in the current archive scope are drawn — see
  `has_visible_bulk_actions?/2` to decide whether to give it any room at all.

  With select all, the bar names the rows a bulk action reaches ("All 99 selected", or "96 selected"
  once rows are unchecked) when the table knows its total (see `bulk_selection_count/1`), and reads
  "All selected" or "All except 3 selected" when it does not.

      <div :if={@show_bulk_actions}>{Shared.render_bulk_actions(assigns)}</div>
  """
  def render_bulk_actions(assigns) do
    static = assigns.static
    state = assigns.state

    hidden_count = hidden_count(state)
    selected_count = MapSet.size(state.selected_ids) - hidden_count
    excluded_count = MapSet.size(state.excluded_ids)
    has_selection = state.select_all? or selected_count + hidden_count > 0

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
      |> assign(:selection_count, bulk_selection_count(state))
      |> assign(:selected_label, selected_label(selected_count, hidden_count))
      |> assign(:visible_bulk_actions, visible_bulk_actions)
      |> assign(:ui_adapter, static.ui_adapter)

    ~H"""
    <.dynamic_component
      :if={@bulk_actions != [] and @has_selection and @visible_bulk_actions != []}
      module={@ui_adapter}
      function={:bulk_action_bar}
      id={@static.id}
      select_all={@select_all}
      selected_count={@selected_count}
      excluded_count={@excluded_count}
      myself={@myself}
      all_selected_label={all_selected_label(@selection_count)}
      all_except_label={all_except_label(@selection_count, @excluded_count)}
      selected_label={@selected_label}
      clear_label={dgettext("mishka_gervaz", "Clear selection")}
    >
      <.dynamic_component
        :for={action <- @visible_bulk_actions}
        module={@ui_adapter}
        function={:bulk_action_button}
        action={action}
        count={@selection_count}
        myself={@myself}
      />
    </.dynamic_component>
    """
  end

  @doc """
  The number of rows a bulk action runs on, or `nil` when the table cannot tell.

  Checked rows the table's read still finds are counted; the ones it hides, such as rows a search
  left out (`hidden_ids`), are not, since the action reaches only rows the read finds. With select
  all, the count is the table's total minus the unchecked rows, and the table can tell only when it
  holds every row or counts its rows (`:numbered` pagination, or `show_total true` in the pagination
  `ui` block).
  """
  @spec bulk_selection_count(map()) :: non_neg_integer() | nil
  def bulk_selection_count(%{select_all?: true} = state) do
    if total_known?(state),
      do: max(state.total_count - MapSet.size(state.excluded_ids), 0),
      else: nil
  end

  def bulk_selection_count(state), do: MapSet.size(state.selected_ids) - hidden_count(state)

  @spec hidden_count(map()) :: non_neg_integer()
  defp hidden_count(%{hidden_ids: %MapSet{} = hidden, selected_ids: picked}),
    do: picked |> MapSet.intersection(hidden) |> MapSet.size()

  defp hidden_count(_state), do: 0

  @spec selected_label(non_neg_integer(), non_neg_integer()) :: String.t()
  defp selected_label(count, 0), do: dgettext("mishka_gervaz", "%{count} selected", count: count)

  defp selected_label(count, hidden),
    do:
      dgettext("mishka_gervaz", "%{count} selected, %{hidden} hidden by the filters",
        count: count,
        hidden: hidden
      )

  @spec all_selected_label(non_neg_integer() | nil) :: String.t()
  defp all_selected_label(nil), do: dgettext("mishka_gervaz", "All selected")

  defp all_selected_label(count),
    do: dgettext("mishka_gervaz", "All %{count} selected", count: count)

  @spec all_except_label(non_neg_integer() | nil, non_neg_integer()) :: String.t()
  defp all_except_label(nil, excluded),
    do: dgettext("mishka_gervaz", "All except %{count} selected", count: excluded)

  defp all_except_label(count, _excluded),
    do: dgettext("mishka_gervaz", "%{count} selected", count: count)

  defp total_known?(%{total_count: total, total_pages: pages})
       when is_integer(total) and is_integer(pages),
       do: true

  defp total_known?(%{total_count: total, has_more?: false}) when is_integer(total), do: true
  defp total_known?(_state), do: false

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

  @doc """
  Whether this record's tick is on, under either selection mode.

  Normally `selected_ids` lists what is ticked; once "select all" is on it is `excluded_ids` that
  lists what has been un-ticked, so the same tick reads from a different set and with the opposite
  sense.
  """
  @spec record_checked?(map(), term()) :: boolean()
  def record_checked?(%{select_all?: true, excluded_ids: excluded}, record_id),
    do: !MapSet.member?(excluded, record_id)

  def record_checked?(%{selected_ids: selected}, record_id),
    do: MapSet.member?(selected, record_id)

  @doc """
  The extra classes the resource asks this record's row to wear, if any.

  `row do class do apply … end end` is where a resource says which records look different.
  Callers compose the result — selection state usually has to win over it.
  """
  @spec custom_row_class(map(), map()) :: list() | String.t() | nil
  def custom_row_class(%{config: config}, record) do
    case get_in(config, [:row, :class, :apply]) do
      apply_fn when is_function(apply_fn, 1) -> apply_fn.(record)
      _absent -> nil
    end
  end

  def custom_row_class(_static, _record), do: nil

  @doc """
  The five "is this part on?" flags a card template's `render/1` opens with.

  Each is a feature flag crossed with whether there is anything to show — `:paginate` alone does not
  mean a pager, it means a pager if the count is known and non-zero.

  Assigns `show_checkboxes`, `show_filters`, `show_pagination`, `show_bulk_actions` and
  `show_switcher`.
  """
  @spec assign_card_flags(map()) :: map()
  def assign_card_flags(%{static: static, state: state} = assigns) do
    features = static.features

    show_checkboxes =
      :select in features and static.bulk_actions != [] and
        has_visible_bulk_actions?(static.bulk_actions, state.archive_status)

    assigns
    |> assign(:show_checkboxes, show_checkboxes)
    |> assign(:show_filters, static.filters != [] and :filter in features)
    |> assign(
      :show_pagination,
      :paginate in features and is_integer(state.total_count) and state.total_count > 0
    )
    |> assign(:show_bulk_actions, :bulk_actions in features and show_checkboxes)
    |> assign(
      :show_switcher,
      static.switchable_templates != nil and static.switchable_templates != []
    )
  end

  defp bulk_action_visible_for_status?(%{visible: :active}, :active), do: true
  defp bulk_action_visible_for_status?(%{visible: :active}, _status), do: false
  defp bulk_action_visible_for_status?(%{visible: :archived}, :archived), do: true
  defp bulk_action_visible_for_status?(%{visible: :archived}, _status), do: false
  defp bulk_action_visible_for_status?(%{visible: nil}, _status), do: true

  defp bulk_action_visible_for_status?(%{visible: visible}, _status) when is_function(visible, 1),
    do: true

  defp bulk_action_visible_for_status?(_, _status), do: true

  defp bulk_action_visible?(
         %{restricted: true} = action,
         archive_status,
         %{master_user?: true} = state
       ),
       do: bulk_action_visible?(Map.delete(action, :restricted), archive_status, state)

  defp bulk_action_visible?(%{restricted: true}, _archive_status, _state), do: false

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

  @doc """
  Renders the Table/Cards switcher for a resource that declared `switchable_templates`.

  Reads `@ui_adapter` when given and falls back to the Tailwind adapter, so it can be called
  from a context that has not resolved one.
  """
  def render_template_switcher(assigns) do
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.UIAdapters.Tailwind
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

  @doc """
  Renders the pagination control — numbered pages, a load-more button or the infinite-scroll
  sentinel, whichever the resource configured.

  Numbered, `:load_more` and `:infinite` tables share one row, `render_pagination_row/1`: the page
  size selector first, the page buttons or Load More in the middle, and last the page info of a
  numbered table or the `range_label/1` of a growing list.

  Reads its labels from `static.pagination_ui`, so `pagination do ui do … end end` on the
  resource is honoured without the template knowing about it.
  """
  def render_pagination(assigns) do
    static = assigns.static
    state = assigns.state
    pagination_ui = static.pagination_ui

    assigns =
      assigns
      |> assign_new(:pagination_type, fn -> pagination_type(static) end)
      |> assign(:static_id, static.id)
      |> assign(:page, state.page)
      |> assign(:has_more?, state.has_more?)
      |> assign(:total_pages, state.total_pages)
      |> assign(:total_count, state.total_count)
      |> assign(:page_size, state.current_page_size || static.page_size)
      |> assign(:current_page_size, state.current_page_size || static.page_size)
      |> assign(:page_size_options, static.page_size_options)
      |> assign(:show_page_size_selector, page_size_selector_enabled?(static))
      |> assign(:loading, state.loading)
      |> assign(:loading_type, state.loading_type)
      |> assign(:ui_adapter, static.ui_adapter)
      |> assign(
        :loading_text,
        translate_text(pagination_ui.loading_text) || dgettext("mishka_gervaz", "Loading...")
      )
      |> assign(
        :load_more_label,
        translate_text(pagination_ui.load_more_label) || dgettext("mishka_gervaz", "Load More")
      )
      |> assign(:show_total, pagination_ui.show_total)
      |> assign(:range_label, range_label(state))
      |> assign(
        :prev_label,
        translate_text(pagination_ui.prev_label) || dgettext("mishka_gervaz", "Previous")
      )
      |> assign(
        :next_label,
        translate_text(pagination_ui.next_label) || dgettext("mishka_gervaz", "Next")
      )
      |> assign(
        :first_label,
        translate_text(pagination_ui.first_label) || dgettext("mishka_gervaz", "First")
      )
      |> assign(
        :last_label,
        translate_text(pagination_ui.last_label) || dgettext("mishka_gervaz", "Last")
      )
      |> assign(
        :page_info_format,
        translate_text(pagination_ui.page_info_format) ||
          dgettext("mishka_gervaz", "Page {page} of {total}")
      )

    ~H"""
    <div
      :if={@loading == :loading and @loading_type == :more}
      class="mt-4 border-t border-[#ecebe6] py-4 text-center"
    >
      <.dynamic_component
        module={@ui_adapter}
        function={:loading_state}
        type={:more}
        style={:spinner}
        text={@loading_text}
        class="inline-flex items-center gap-2 text-[12.5px] font-medium text-[#8a877f]"
      />
    </div>

    <div
      :if={@pagination_type == :infinite and not @has_more? and @loading != :loading and @page > 1}
      class="mt-4 border-t border-[#ecebe6] py-4 text-center text-[11px] font-medium text-[#a8a5a0]"
    >
      {dgettext("mishka_gervaz", "End of results")}
    </div>

    <.render_pagination_row :if={@pagination_type in [:load_more, :infinite]}>
      <:leading :if={@show_page_size_selector}>
        <.render_page_size_selector
          static_id={@static_id}
          page_size_options={@page_size_options}
          current_page_size={@current_page_size}
          myself={@myself}
        />
      </:leading>
      <:center :if={@pagination_type == :load_more and @has_more? and @loading != :loading}>
        <button
          type="button"
          phx-click="load_more"
          phx-target={@myself}
          class="h-[42px] rounded-[12px] border border-[#dcdbf5] bg-[#f2f1fc] px-[22px] text-[12.5px] font-bold text-[#4f4bcc] transition-colors hover:bg-[#e9e7fb]"
        >
          {@load_more_label}
        </button>
      </:center>
      <:trailing :if={@range_label}>{@range_label}</:trailing>
    </.render_pagination_row>

    <.render_numbered_pagination
      :if={@pagination_type == :numbered and @total_pages}
      static_id={@static_id}
      page={@page}
      total_pages={@total_pages}
      total_count={@total_count}
      page_size={@page_size}
      current_page_size={@current_page_size}
      page_size_options={@page_size_options}
      show_page_size_selector={@show_page_size_selector}
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

  @doc """
  Renders the Load earlier button that goes above the rows of a `:load_more` or `:infinite` table
  opened past its first page, as a reload after Load more opens it. A click sends `"load_earlier"`,
  which reads the page before the first one shown and puts its rows above them, one page a click,
  until the first page. Nothing is drawn while a load runs, nor on a table that shows its first
  page.

      <Shared.render_load_earlier static={@static} state={@state} myself={@myself} />
  """
  @spec render_load_earlier(map()) :: Phoenix.LiveView.Rendered.t()
  def render_load_earlier(assigns) do
    assigns = assign(assigns, :earlier?, earlier?(assigns.static, assigns.state))

    ~H"""
    <div :if={@earlier?} class="mb-[14px] flex items-center justify-center">
      <button
        type="button"
        phx-click="load_earlier"
        phx-target={@myself}
        class="h-[42px] rounded-[12px] border border-[#dcdbf5] bg-[#f2f1fc] px-[22px] text-[12.5px] font-bold text-[#4f4bcc] transition-colors hover:bg-[#e9e7fb]"
      >
        {dgettext("mishka_gervaz", "Load earlier")}
      </button>
    </div>
    """
  end

  @spec earlier?(map(), map()) :: boolean()
  defp earlier?(static, state) do
    pagination_type(static) in [:load_more, :infinite] and state.first_page > 1 and
      state.loading != :loading
  end

  defp render_numbered_pagination(assigns) do
    ~H"""
    <.render_pagination_row>
      <:leading :if={@show_page_size_selector}>
        <.render_page_size_selector
          static_id={@static_id}
          page_size_options={@page_size_options}
          current_page_size={@current_page_size}
          myself={@myself}
        />
      </:leading>
      <:center :if={@total_pages > 1}>
        <.dynamic_component
          module={@ui_adapter}
          function={:pagination_nav_button}
          label={@prev_label}
          event="prev_page"
          myself={@myself}
          disabled={@page <= 1 or @loading == :loading}
        />
        <.render_page_numbers
          page={@page}
          total_pages={@total_pages}
          myself={@myself}
          loading={@loading}
          ui_adapter={@ui_adapter}
        />
        <.dynamic_component
          module={@ui_adapter}
          function={:pagination_nav_button}
          label={@next_label}
          event="next_page"
          myself={@myself}
          disabled={@page >= @total_pages or @loading == :loading}
        />
      </:center>
      <:trailing :if={@show_total}>
        {format_page_info(@page_info_format, @page, @total_pages, @total_count)}
      </:trailing>
    </.render_pagination_row>
    """
  end

  @doc """
  Lays out the row under a table's rows in three parts on one line: `leading` at the start,
  `center` in the middle and `trailing` at the end. The middle part stays in the middle of the row
  whatever the widths of the other two, and wraps its buttons when the row is too narrow for them,
  while the last part keeps its words on one line. Below 640px the parts stack, each centred, so
  the row never scrolls sideways. A part left out keeps its place on a wide screen and takes no
  line on a narrow one.

  `render_pagination/1` draws every pager with it: the page size selector first, Load More or the
  page buttons in the middle, and last where the reader is (`range_label/1` on a `:load_more` or
  `:infinite` table, the page info on a numbered one). A template that draws its own pager lays it
  out with this to look like every other table.

      <Shared.render_pagination_row>
        <:leading>…</:leading>
        <:center>…</:center>
        <:trailing>{Shared.range_label(@state)}</:trailing>
      </Shared.render_pagination_row>
  """
  slot :leading, doc: "the first part, such as the page size selector"
  slot :center, doc: "the middle part, such as Load More or the page buttons"
  slot :trailing, doc: "the last part, such as where the reader is in the list"

  @spec render_pagination_row(map()) :: Phoenix.LiveView.Rendered.t()
  def render_pagination_row(assigns) do
    ~H"""
    <div
      data-role="gervaz-pagination"
      class="mt-[22px] grid grid-cols-[1fr_auto_1fr] items-center gap-3 text-[12px] font-semibold text-[#a8a5a0] max-[640px]:grid-cols-1 max-[640px]:justify-items-center"
    >
      <div
        data-role="gervaz-pagination-leading"
        class={["flex items-center", @leading == [] && "max-[640px]:hidden"]}
      >
        {render_slot(@leading)}
      </div>
      <div
        data-role="gervaz-pagination-center"
        class={[
          "flex flex-wrap items-center justify-center gap-1.5",
          @center == [] && "max-[640px]:hidden"
        ]}
      >
        {render_slot(@center)}
      </div>
      <div
        data-role="gervaz-pagination-trailing"
        class={[
          "flex items-center justify-end whitespace-nowrap text-end max-[640px]:justify-center max-[640px]:text-center",
          @trailing == [] && "max-[640px]:hidden"
        ]}
      >
        {render_slot(@trailing)}
      </div>
    </div>
    """
  end

  @doc """
  Where the reader is in a `:load_more` or `:infinite` list: `Showing 1–40 of 136`, from the first
  row shown to the last, of the table's total. A list opened at page 3 of 20-row pages starts at 41
  until Load earlier brings the pages before it. The last row is `state.next_offset`, the end of the
  rows the view shows, so a row the view took out is not counted. A page past the last reads
  `Showing 0 of 136`.

  `nil` when the table keeps no count (`show_total false`) or holds no rows.
  """
  @spec range_label(map()) :: String.t() | nil
  def range_label(
        %{
          static: %{pagination_ui: %{show_total: true}},
          total_count: total,
          page: page,
          first_page: first_page
        } = state
      )
      when is_integer(total) and total > 0 and is_integer(page) and is_integer(first_page) do
    page_size = state.current_page_size || state.static.page_size
    first = (first_page - 1) * page_size + 1
    last = min(shown_end(state, page_size), total)

    case first <= last and not MishkaGervaz.Table.Web.Renderer.past_last_page?(state) do
      true ->
        dgettext("mishka_gervaz", "Showing %{first}–%{last} of %{total}",
          first: first,
          last: last,
          total: total
        )

      false ->
        dgettext("mishka_gervaz", "Showing 0 of %{total}", total: total)
    end
  end

  def range_label(_state), do: nil

  @spec shown_end(map(), pos_integer()) :: non_neg_integer()
  defp shown_end(%{next_offset: offset}, _page_size) when is_integer(offset) and offset > 0,
    do: offset

  defp shown_end(%{page: page}, page_size), do: page * page_size

  defp render_page_size_selector(assigns) do
    ~H"""
    <form
      id={@static_id <> "-page-size-selector-form"}
      phx-change="change_page_size"
      phx-target={@myself}
      class="flex items-center gap-[9px]"
    >
      <span id={@static_id <> "-page-size-show"} class="text-[12px] font-semibold text-[#8a877f]">
        {dgettext("mishka_gervaz", "Show")}
      </span>
      <div class="relative">
        <select
          name="size"
          aria-labelledby={"#{@static_id}-page-size-show #{@static_id}-page-size-unit"}
          class="h-[36px] cursor-pointer appearance-none rounded-[9px] border border-[#ecebe6] bg-white ps-[12px] pe-[30px] text-[12.5px] font-semibold text-[#3a382f] outline-none"
        >
          <option :for={opt <- @page_size_options} value={opt} selected={opt == @current_page_size}>
            {opt}
          </option>
        </select>
        <svg
          class="pointer-events-none absolute end-[10px] top-1/2 -translate-y-1/2"
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#a8a5a0"
          stroke-width="2.4"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="m6 9 6 6 6-6" />
        </svg>
      </div>
      <span id={@static_id <> "-page-size-unit"} class="text-[12px] font-semibold text-[#8a877f]">
        {dgettext("mishka_gervaz", "per page")}
      </span>
    </form>
    """
  end

  defp page_size_selector_enabled?(static) do
    static.page_size_options != nil and static.page_size_options != []
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
          <span class="px-2 py-1 text-[12px] font-medium text-[#8a877f]">...</span>
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

  @doc """
  Renders one row's action strip: the inline buttons, then any dropdown.

  Honours `actions_layout` placement and each action's `visible` rule, and leaves
  `:accordion` actions out — the caret is the table's own, not a button. Expects `@record`,
  `@static`, `@state` and `@myself`.
  """
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
    <div class="flex items-center gap-1">
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

    dropdown_ui = assigns.dropdown[:ui] || %{}
    icon = dropdown_ui[:icon] || "hero-ellipsis-vertical"

    assigns =
      assigns
      |> Phoenix.Component.assign(:visible_items, visible_items)
      |> Phoenix.Component.assign(:has_visible?, has_visible?)
      |> Phoenix.Component.assign(:icon, icon)

    ~H"""
    <div :if={@has_visible?}>
      <.dynamic_component module={@static.ui_adapter} function={:dropdown} icon={@icon}>
        <.render_dropdown_item
          :for={{item, idx} <- Enum.with_index(@visible_items)}
          :if={item[:type] != :separator or render_separator?(@visible_items, idx)}
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
    assigns = assign(assigns, :separator_label, resolve_label(assigns.item[:label]))

    ~H"""
    <div class="my-1 border-t border-[#f0efea] pt-1">
      <div
        :if={@separator_label}
        class="px-2.5 py-1 text-[9.5px] font-bold uppercase tracking-[0.06em] text-[#a8a5a0]"
      >
        {@separator_label}
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

  defp render_separator?(items, index) do
    {before, [_separator | below]} = Enum.split(items, index)
    Enum.any?(before, &menu_item?/1) and menu_item?(List.first(below))
  end

  defp menu_item?(%{type: :separator}), do: false
  defp menu_item?(item), do: is_map(item)

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

  @doc """
  The row actions a template should draw as buttons — everything except an `:accordion`.

  An `:accordion` action is a declaration that the row expands, not a button: a template renders the
  caret itself, wherever its design puts it.
  """
  @spec non_accordion_actions([map()]) :: [map()]
  def non_accordion_actions(row_actions) do
    Enum.reject(row_actions, &(&1[:type] == :accordion))
  end

  @doc """
  Whether some row of the table may expand for the reader: an `:accordion` action that is not
  `restricted` from them and whose `visible` is not `false`, nor the other archive view's
  (`:active` / `:archived`). A `visible fn record, state` is asked per row, by `expandable?/3`.

  A template draws its caret column when this is true, so a row without a caret keeps the
  table's columns.
  """
  @spec expandable_rows?([map()], map()) :: boolean()
  def expandable_rows?(row_actions, state) do
    Enum.any?(row_actions, &(&1[:type] == :accordion and may_show?(&1, state)))
  end

  @doc """
  Whether this row expands: one of the table's `:accordion` actions is visible for the record, as
  `action_visible?/3` answers for every row action, and is not `restricted` from the reader. A
  template draws the row's caret, and its expanded details, only then.
  """
  @spec expandable?([map()], map(), map()) :: boolean()
  def expandable?(row_actions, record, state) do
    Enum.any?(row_actions, fn action ->
      action[:type] == :accordion and action_visible?(action, record, state) and
        action_authorized?(action, record, state)
    end)
  end

  defp may_show?(%{visible: visible} = action, state) when is_function(visible, 2),
    do: action_authorized?(action, nil, state)

  defp may_show?(action, state),
    do: action_visible?(action, nil, state) and action_authorized?(action, nil, state)

  defp action_authorized?(%{restricted: true}, _record, %{master_user?: master?}), do: master?

  defp action_authorized?(_, _record, _state), do: true

  @doc """
  Checks if any row actions or dropdowns are potentially visible for the current user.

  Used by templates to decide whether to render the Actions column header.
  Does not evaluate per-record visibility functions — only checks `restricted` and
  boolean/atom `visible` values.
  """
  @spec has_user_visible_actions?(list(), list() | nil, map()) :: boolean()
  def has_user_visible_actions?(row_actions, dropdowns, state) do
    action_available? = fn action ->
      not (action[:restricted] == true and not state.master_user?) and
        action[:visible] != false and
        action[:type] != :accordion
    end

    has_actions = Enum.any?(row_actions, action_available?)

    has_dropdowns =
      case dropdowns do
        items when is_list(items) and items != [] ->
          Enum.any?(items, fn dropdown ->
            Enum.any?(Map.get(dropdown, :items, []), fn item ->
              item[:type] == :separator or action_available?.(item)
            end)
          end)

        _ ->
          false
      end

    has_actions or has_dropdowns
  end

  @doc """
  Renders the empty state with configurable message, icon, and action.

  On a page past the table's last one (`MishkaGervaz.Table.Web.Renderer.past_last_page?/1`) it
  says the page has no rows and its action is a button that opens page 1, in place of the
  configured message and action.
  """
  @spec render_empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def render_empty_state(assigns) do
    empty_state = assigns[:empty_state] || %{}
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.UIAdapters.Tailwind

    assigns =
      assigns
      |> assign(
        :message,
        translate_text(
          Map.get(empty_state, :message, dgettext("mishka_gervaz", "No records found"))
        )
      )
      |> assign(:icon, Map.get(empty_state, :icon, "hero-inbox"))
      |> assign(:action_label, translate_text(get_in(empty_state, [:action, :label])))
      |> assign(:action_path, get_in(empty_state, [:action, :path]))
      |> assign(:action_icon, get_in(empty_state, [:action, :icon]))
      |> assign(:action_click, nil)
      |> assign(:ui_adapter, ui_adapter)
      |> assign_past_last_page()

    ~H"""
    <.dynamic_component
      module={@ui_adapter}
      function={:empty_state}
      message={@message}
      icon={@icon}
      action_label={@action_label}
      action_path={@action_path}
      action_icon={@action_icon}
      action_click={@action_click}
    />
    """
  end

  @spec assign_past_last_page(map()) :: map()
  defp assign_past_last_page(%{state: %{} = state} = assigns) do
    if MishkaGervaz.Table.Web.Renderer.past_last_page?(state) do
      assigns
      |> assign(:message, dgettext("mishka_gervaz", "No rows on this page"))
      |> assign(:action_label, dgettext("mishka_gervaz", "Go to page 1"))
      |> assign(:action_path, nil)
      |> assign(:action_icon, "hero-arrow-uturn-left")
      |> assign(
        :action_click,
        JS.push("go_to_page", value: %{page: 1}, target: assigns[:myself])
      )
    else
      assigns
    end
  end

  defp assign_past_last_page(assigns), do: assigns

  @doc """
  Renders the error state with configurable message, icon, and retry button.
  """
  @spec render_error_state(map()) :: Phoenix.LiveView.Rendered.t()
  def render_error_state(assigns) do
    error_state = assigns[:error_state] || %{}
    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.UIAdapters.Tailwind

    assigns =
      assigns
      |> assign(
        :message,
        translate_text(
          Map.get(error_state, :message, dgettext("mishka_gervaz", "Error loading data"))
        )
      )
      |> assign(:icon, Map.get(error_state, :icon))
      |> assign(
        :retry_label,
        translate_text(Map.get(error_state, :retry_label, dgettext("mishka_gervaz", "Retry")))
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
  Which pager a resource asked for — numbered pages, a Load-more button, or infinite scroll.

  `render_pagination/1` reads this itself when the caller has not already assigned it, so a template
  only passes `pagination_type` when it wants to override what the resource declared.
  """
  @spec pagination_type(map()) :: atom()
  def pagination_type(static), do: get_in(static.config, [:pagination, :type]) || :numbered

  @doc """
  No header at all — the default for a template whose page already names itself.

  Returns an empty template.
  """
  @spec render_header(map()) :: Phoenix.LiveView.Rendered.t()
  def render_header(assigns), do: ~H""

  @doc """
  Renders the loading state with spinner and configurable text.
  """
  @spec render_loading(map()) :: Phoenix.LiveView.Rendered.t()
  def render_loading(assigns) do
    loading_text =
      translate_text(assigns[:loading_text]) || dgettext("mishka_gervaz", "Loading...")

    ui_adapter = assigns[:ui_adapter] || MishkaGervaz.UIAdapters.Tailwind
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

  @doc """
  Renders one cell the way the plain table does — `format` first, then the column's `render`
  if it has one, then its type module, then the bare value.

  A custom template should call this rather than reading the value itself, or a column's
  `render` and `ui do type … end` stop working inside it.

      <td :for={column <- @columns}>{Shared.render_cell(%{column: column, record: @record, static: @static, state: @state})}</td>
  """
  def render_cell(assigns) do
    {column, record, static, state} =
      {assigns.column, assigns.record, assigns[:static], assigns[:state]}

    ui = (static && static.ui_adapter) || MishkaGervaz.UIAdapters.Tailwind
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
        column_with_id = Map.put(column, :__table_id__, static && static.id)
        column.type_module.render(formatted_value, column_with_id, record, ui)

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

  @doc """
  Builds active filter chip data for custom templates.

  Returns `{visible_chips, has_any_active_filters}` where:
  - `visible_chips` excludes `visible: false` filters (hidden from UI but still active in state)
  - `has_any_active_filters` is true if any filter has a value (including hidden ones)

  Use `has_any_active_filters` for the "Clear all" button visibility so users can always
  clear hidden filters (e.g., `id` filter from URL).
  """
  @spec build_active_filter_chips(map(), map()) :: {list(map()), boolean()}
  def build_active_filter_chips(state, static) do
    all_active =
      Enum.filter(state.filter_values, fn {_k, v} -> has_chip_value?(v) end)

    has_any = all_active != []

    chips =
      all_active
      |> Enum.reject(fn {name, _v} ->
        match?(%{visible: false}, Enum.find(static.filters, &(&1.name == name)))
      end)
      |> Enum.map(fn {name, value} ->
        filter = Enum.find(static.filters, &(&1.name == name))

        label =
          if filter,
            do: resolve_ui_label(filter) || translate_text(Phoenix.Naming.humanize(name)),
            else: translate_text(Phoenix.Naming.humanize(name))

        display_value = resolve_chip_value(name, value, state)
        %{name: name, value: value, label: label, display_value: display_value}
      end)

    {chips, has_any}
  end

  @doc "Resolve a filter chip's display value, using relation labels when available."
  @spec resolve_chip_value(atom(), term(), map()) :: String.t()
  def resolve_chip_value(name, value, state) do
    case Map.get(state.relation_filter_state || %{}, name) do
      %{selected_options: options} when is_list(options) and options != [] ->
        if is_list(value) do
          value
          |> Enum.map(fn v ->
            case Enum.find(options, fn {_label, ov} -> ov == v end) do
              {label, _} -> label
              _ -> v
            end
          end)
          |> Enum.join(", ")
        else
          case Enum.find(options, fn {_label, v} -> v == value end) do
            {label, _v} -> label
            _ -> format_chip_value(value)
          end
        end

      _ ->
        format_chip_value(value)
    end
  end

  @doc "Check if a filter value is meaningful (non-nil, non-empty)."
  @spec has_chip_value?(term()) :: boolean()
  def has_chip_value?(nil), do: false
  def has_chip_value?(""), do: false
  def has_chip_value?([]), do: false
  def has_chip_value?(%{} = map) when map_size(map) == 0, do: false
  def has_chip_value?(_), do: true

  @doc "Format a filter value for display in a chip."
  @spec format_chip_value(term()) :: String.t()
  def format_chip_value(value) when is_boolean(value), do: to_string(value)

  def format_chip_value(value) when is_atom(value),
    do: translate_text(Phoenix.Naming.humanize(value))

  def format_chip_value(value) when is_binary(value), do: value
  def format_chip_value(value) when is_list(value), do: Enum.join(value, ", ")
  def format_chip_value(%{} = value), do: inspect(value)
  def format_chip_value(value), do: to_string(value)
end
