defmodule MishkaGervaz.UIAdapters.Dynamic do
  @moduledoc """
  Dynamic UI adapter for database-driven components.

  This adapter allows components to be loaded from a database and rendered dynamically.
  It requires injecting a component renderer function that handles the actual rendering.

  ## Configuration

  Set this adapter in your DSL along with the required callbacks:

      presentation do
        ui_adapter :dynamic
        ui_adapter_opts [
          site: "Global",
          component_renderer: &MishkaCmsCoreResources.Runtime.LiveViewHelpers.component/1,
          module_resolver: &MishkaCmsCoreResources.Runtime.Compilers.Helpers.module_name/3,
          fallback: MishkaGervaz.UIAdapters.Tailwind
        ]
      end

  ## Options

  - `:site` - Site identifier for component lookup (default: "Global")
  - `:component_renderer` - Function that renders a component given assigns with `:component_name` and `:site`
  - `:module_resolver` - Function `(id, site, type) -> module()` to check component availability
  - `:fallback` - Fallback adapter when component not found (default: Tailwind)

  ## Component Naming

  The adapter looks for components with these names in the database:
  - `text_input` - Text input component
  - `select` - Select dropdown component
  - `button` - Button component
  - `table` - Table wrapper component
  - `badge`, `icon`, `spinner`, `checkbox`, etc.

  If a component is not found or renderer is not configured, it falls back to the
  specified fallback adapter (defaults to Tailwind).
  """

  @behaviour MishkaGervaz.Behaviours.UIAdapter
  use Phoenix.Component

  @default_site "Global"
  @default_fallback MishkaGervaz.UIAdapters.Tailwind

  @component_functions [
    :text_input,
    :select,
    :multi_select,
    :search_select,
    :checkbox,
    :date_input,
    :datetime_input,
    :date_range_container,
    :number_input,
    :button,
    :nav_link,
    :icon,
    :badge,
    :spinner,
    :table,
    :table_header,
    :th,
    :tr,
    :td,
    :dropdown,
    :empty_state,
    :error_state,
    :cell_empty,
    :cell_text,
    :cell_number,
    :cell_date,
    :cell_datetime,
    :cell_code,
    :cell_array,
    :filter_reset_button,
    :archive_toggle,
    :bulk_action_bar,
    :bulk_action_button,
    :pagination_container,
    :pagination_nav_button,
    :pagination_page_button,
    :loading_state,
    :template_switcher,
    :template_switcher_button,
    # Form-only (17)
    :form_container,
    :field_wrapper,
    :field_group,
    :step_indicator,
    :step_navigation,
    :upload_dropzone,
    :upload_preview,
    :upload_progress,
    :upload_file_input,
    :upload_existing_file,
    :toggle_input,
    :range_input,
    :textarea,
    :json_editor,
    :nested_fields,
    :array_fields,
    :field_error,
    :string_list_input,
    :combobox
  ]

  @doc """
  Use this module to create a Dynamic adapter with pre-configured options.

  ## Options

    * `:site` - Site identifier for component lookup (default: "Global")
    * `:fallback` - Fallback adapter when component not found (default: Tailwind)
    * `:component_renderer` - Function `(assigns) -> rendered` to render components
    * `:module_resolver` - Function `(id, site, type) -> module()` to resolve module names

  ## Example

      defmodule MyApp.GervazUIAdapter do
        use MishkaGervaz.UIAdapters.Dynamic,
          site: "Global",
          component_renderer: &MyApp.LiveViewHelpers.component/1,
          module_resolver: &MyApp.Compilers.Helpers.module_name/3,
          fallback: MishkaGervaz.UIAdapters.Tailwind
      end
  """
  defmacro __using__(opts) do
    site = Keyword.get(opts, :site, "Global")
    fallback = Keyword.get(opts, :fallback, MishkaGervaz.UIAdapters.Tailwind)
    component_renderer = Keyword.get(opts, :component_renderer)
    module_resolver = Keyword.get(opts, :module_resolver)

    component_wrappers =
      for func <- @component_functions do
        quote do
          def unquote(func)(assigns) do
            MishkaGervaz.UIAdapters.Dynamic.unquote(func)(inject_config(assigns))
          end
        end
      end

    quote do
      @behaviour MishkaGervaz.Behaviours.UIAdapter
      use Phoenix.Component

      @site unquote(site)
      @fallback unquote(fallback)
      @component_renderer unquote(component_renderer)
      @module_resolver unquote(module_resolver)

      defp inject_config(assigns) do
        assigns
        |> Map.put(:__site__, @site)
        |> Map.put(:__fallback__, @fallback)
        |> maybe_put(:__component_renderer__, @component_renderer)
        |> maybe_put(:__module_resolver__, @module_resolver)
      end

      defp maybe_put(map, _key, nil), do: map
      defp maybe_put(map, key, value), do: Map.put(map, key, value)

      unquote_splicing(component_wrappers)
    end
  end

  @impl true
  def text_input(assigns) do
    render_component("text_input", assigns, fn assigns ->
      fallback(assigns).text_input(assigns)
    end)
  end

  @impl true
  def select(assigns) do
    render_component("select", assigns, fn assigns ->
      fallback(assigns).select(assigns)
    end)
  end

  @impl true
  def checkbox(assigns) do
    render_component("checkbox", assigns, fn assigns ->
      fallback(assigns).checkbox(assigns)
    end)
  end

  @impl true
  def date_input(assigns) do
    render_component("date_input", assigns, fn assigns ->
      fallback(assigns).date_input(assigns)
    end)
  end

  @impl true
  def datetime_input(assigns) do
    render_component("datetime_input", assigns, fn assigns ->
      fallback(assigns).datetime_input(assigns)
    end)
  end

  @impl true
  def number_input(assigns) do
    render_component("number_input", assigns, fn assigns ->
      fallback(assigns).number_input(assigns)
    end)
  end

  @impl true
  def button(assigns) do
    render_component("button", assigns, fn assigns ->
      fallback(assigns).button(assigns)
    end)
  end

  @impl true
  def nav_link(assigns) do
    render_component("nav_link", assigns, fn assigns ->
      fallback(assigns).nav_link(assigns)
    end)
  end

  @impl true
  def icon(assigns) do
    render_component("icon", assigns, fn assigns ->
      fallback(assigns).icon(assigns)
    end)
  end

  @impl true
  def badge(assigns) do
    render_component("badge", assigns, fn assigns ->
      fallback(assigns).badge(assigns)
    end)
  end

  @impl true
  def spinner(assigns) do
    render_component("spinner", assigns, fn assigns ->
      fallback(assigns).spinner(assigns)
    end)
  end

  @impl true
  def table(assigns) do
    render_component("table", assigns, fn assigns ->
      fallback(assigns).table(assigns)
    end)
  end

  @impl true
  def table_header(assigns) do
    render_component("table_header", assigns, fn assigns ->
      fallback(assigns).table_header(assigns)
    end)
  end

  @impl true
  def th(assigns) do
    render_component("th", assigns, fn assigns ->
      fallback(assigns).th(assigns)
    end)
  end

  @impl true
  def tr(assigns) do
    render_component("tr", assigns, fn assigns ->
      fallback(assigns).tr(assigns)
    end)
  end

  @impl true
  def td(assigns) do
    render_component("td", assigns, fn assigns ->
      fallback(assigns).td(assigns)
    end)
  end

  @impl true
  def dropdown(assigns) do
    render_component("dropdown", assigns, fn assigns ->
      fallback(assigns).dropdown(assigns)
    end)
  end

  @impl true
  def empty_state(assigns) do
    render_component("empty_state", assigns, fn assigns ->
      fallback(assigns).empty_state(assigns)
    end)
  end

  @impl true
  def error_state(assigns) do
    render_component("error_state", assigns, fn assigns ->
      fallback(assigns).error_state(assigns)
    end)
  end

  @impl true
  def date_range_container(assigns) do
    render_component("date_range_container", assigns, fn assigns ->
      fallback(assigns).date_range_container(assigns)
    end)
  end

  @impl true
  def cell_empty(assigns) do
    render_component("cell_empty", assigns, fn assigns ->
      fallback(assigns).cell_empty(assigns)
    end)
  end

  @impl true
  def cell_text(assigns) do
    render_component("cell_text", assigns, fn assigns ->
      fallback(assigns).cell_text(assigns)
    end)
  end

  @impl true
  def cell_number(assigns) do
    render_component("cell_number", assigns, fn assigns ->
      fallback(assigns).cell_number(assigns)
    end)
  end

  @impl true
  def cell_date(assigns) do
    render_component("cell_date", assigns, fn assigns ->
      fallback(assigns).cell_date(assigns)
    end)
  end

  @impl true
  def cell_datetime(assigns) do
    render_component("cell_datetime", assigns, fn assigns ->
      fallback(assigns).cell_datetime(assigns)
    end)
  end

  @impl true
  def cell_code(assigns) do
    render_component("cell_code", assigns, fn assigns ->
      fallback(assigns).cell_code(assigns)
    end)
  end

  @impl true
  def cell_array(assigns) do
    render_component("cell_array", assigns, fn assigns ->
      fallback(assigns).cell_array(assigns)
    end)
  end

  @impl true
  def multi_select(assigns) do
    render_component("multi_select", assigns, fn assigns ->
      fallback(assigns).multi_select(assigns)
    end)
  end

  @impl true
  def filter_reset_button(assigns) do
    render_component("filter_reset_button", assigns, fn assigns ->
      fallback(assigns).filter_reset_button(assigns)
    end)
  end

  @impl true
  def archive_toggle(assigns) do
    render_component("archive_toggle", assigns, fn assigns ->
      fallback(assigns).archive_toggle(assigns)
    end)
  end

  @impl true
  def bulk_action_bar(assigns) do
    render_component("bulk_action_bar", assigns, fn assigns ->
      fallback(assigns).bulk_action_bar(assigns)
    end)
  end

  @impl true
  def bulk_action_button(assigns) do
    render_component("bulk_action_button", assigns, fn assigns ->
      fallback(assigns).bulk_action_button(assigns)
    end)
  end

  @impl true
  def pagination_container(assigns) do
    render_component("pagination_container", assigns, fn assigns ->
      fallback(assigns).pagination_container(assigns)
    end)
  end

  @impl true
  def pagination_nav_button(assigns) do
    render_component("pagination_nav_button", assigns, fn assigns ->
      fallback(assigns).pagination_nav_button(assigns)
    end)
  end

  @impl true
  def pagination_page_button(assigns) do
    render_component("pagination_page_button", assigns, fn assigns ->
      fallback(assigns).pagination_page_button(assigns)
    end)
  end

  @impl true
  def loading_state(assigns) do
    render_component("loading_state", assigns, fn assigns ->
      fallback(assigns).loading_state(assigns)
    end)
  end

  @impl true
  def template_switcher(assigns) do
    render_component("template_switcher", assigns, fn assigns ->
      fallback(assigns).template_switcher(assigns)
    end)
  end

  @impl true
  def template_switcher_button(assigns) do
    render_component("template_switcher_button", assigns, fn assigns ->
      fallback(assigns).template_switcher_button(assigns)
    end)
  end

  @impl true
  def search_select(assigns) do
    render_component("search_select", assigns, fn assigns ->
      fallback(assigns).search_select(assigns)
    end)
  end

  @impl true
  def load_more_select(assigns) do
    render_component("load_more_select", assigns, fn assigns ->
      fallback(assigns).load_more_select(assigns)
    end)
  end

  @impl true
  def form_container(assigns) do
    render_component("form_container", assigns, fn assigns ->
      fallback(assigns).form_container(assigns)
    end)
  end

  @impl true
  def field_wrapper(assigns) do
    render_component("field_wrapper", assigns, fn assigns ->
      fallback(assigns).field_wrapper(assigns)
    end)
  end

  @impl true
  def field_group(assigns) do
    render_component("field_group", assigns, fn assigns ->
      fallback(assigns).field_group(assigns)
    end)
  end

  @impl true
  def step_indicator(assigns) do
    render_component("step_indicator", assigns, fn assigns ->
      fallback(assigns).step_indicator(assigns)
    end)
  end

  @impl true
  def step_navigation(assigns) do
    render_component("step_navigation", assigns, fn assigns ->
      fallback(assigns).step_navigation(assigns)
    end)
  end

  @impl true
  def upload_dropzone(assigns) do
    render_component("upload_dropzone", assigns, fn assigns ->
      fallback(assigns).upload_dropzone(assigns)
    end)
  end

  @impl true
  def upload_preview(assigns) do
    render_component("upload_preview", assigns, fn assigns ->
      fallback(assigns).upload_preview(assigns)
    end)
  end

  @impl true
  def upload_progress(assigns) do
    render_component("upload_progress", assigns, fn assigns ->
      fallback(assigns).upload_progress(assigns)
    end)
  end

  @impl true
  def upload_file_input(assigns) do
    render_component("upload_file_input", assigns, fn assigns ->
      fallback(assigns).upload_file_input(assigns)
    end)
  end

  @impl true
  def upload_existing_file(assigns) do
    render_component("upload_existing_file", assigns, fn assigns ->
      fallback(assigns).upload_existing_file(assigns)
    end)
  end

  @impl true
  def toggle_input(assigns) do
    render_component("toggle_input", assigns, fn assigns ->
      fallback(assigns).toggle_input(assigns)
    end)
  end

  @impl true
  def range_input(assigns) do
    render_component("range_input", assigns, fn assigns ->
      fallback(assigns).range_input(assigns)
    end)
  end

  @impl true
  def textarea(assigns) do
    render_component("textarea", assigns, fn assigns ->
      fallback(assigns).textarea(assigns)
    end)
  end

  @impl true
  def json_editor(assigns) do
    render_component("json_editor", assigns, fn assigns ->
      fallback(assigns).json_editor(assigns)
    end)
  end

  @impl true
  def nested_fields(assigns) do
    render_component("nested_fields", assigns, fn assigns ->
      fallback(assigns).nested_fields(assigns)
    end)
  end

  @impl true
  def array_fields(assigns) do
    render_component("array_fields", assigns, fn assigns ->
      fallback(assigns).array_fields(assigns)
    end)
  end

  @impl true
  def field_error(assigns) do
    render_component("field_error", assigns, fn assigns ->
      fallback(assigns).field_error(assigns)
    end)
  end

  @impl true
  def string_list_input(assigns) do
    render_component("string_list_input", assigns, fn assigns ->
      fallback(assigns).string_list_input(assigns)
    end)
  end

  @impl true
  def combobox(assigns) do
    render_component("combobox", assigns, fn assigns ->
      fallback(assigns).combobox(assigns)
    end)
  end

  defp render_component(component_name, assigns, fallback_fn) do
    renderer = Map.get(assigns, :__component_renderer__)
    resolver = Map.get(assigns, :__module_resolver__)
    site = Map.get(assigns, :__site__, @default_site)

    if is_function(renderer, 1) and component_available?(resolver, component_name, site) do
      component_assigns =
        assigns
        |> Map.put(:component_name, component_name)
        |> Map.put(:site, site)

      renderer.(component_assigns)
    else
      fallback_fn.(assigns)
    end
  end

  @spec component_available?(function() | nil, String.t(), String.t()) :: boolean()
  defp component_available?(nil, _component_name, _site), do: false

  defp component_available?(resolver, component_name, site) when is_function(resolver, 3) do
    module = resolver.(component_name, site, "Component")
    :erlang.module_loaded(module)
  end

  defp component_available?(_resolver, _component_name, _site), do: false

  defp fallback(assigns) do
    Map.get(assigns, :__fallback__, @default_fallback)
  end

  @doc """
  Creates a set of assigns with Dynamic adapter configuration.

  This helper function adds the necessary metadata for the Dynamic adapter
  to work correctly with the runtime component system.

  ## Options

  - `:site` - The site identifier for component lookup (default: "Global")
  - `:component_renderer` - Function `(assigns) -> rendered` to render components
  - `:module_resolver` - Function `(id, site, type) -> module()` to resolve module names
  - `:fallback` - The fallback adapter to use when components are not found
    (default: `MishkaGervaz.UIAdapters.Tailwind`)

  ## Example

      assigns = MishkaGervaz.UIAdapters.Dynamic.with_config(assigns,
        site: "MyApp",
        component_renderer: &MishkaCmsCoreResources.Runtime.LiveViewHelpers.component/1,
        module_resolver: &MishkaCmsCoreResources.Runtime.Compilers.Helpers.module_name/3,
        fallback: MishkaGervaz.UIAdapters.Chelekom
      )
  """
  def with_config(assigns, opts \\ []) do
    site = Keyword.get(opts, :site, @default_site)
    fallback = Keyword.get(opts, :fallback, @default_fallback)
    component_renderer = Keyword.get(opts, :component_renderer)
    module_resolver = Keyword.get(opts, :module_resolver)

    assigns
    |> Map.put(:__site__, site)
    |> Map.put(:__fallback__, fallback)
    |> maybe_put(:__component_renderer__, component_renderer)
    |> maybe_put(:__module_resolver__, module_resolver)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
