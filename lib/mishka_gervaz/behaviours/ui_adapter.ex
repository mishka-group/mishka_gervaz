defmodule MishkaGervaz.Behaviours.UIAdapter do
  @moduledoc """
  Behaviour for UI component adapters.

  Implement this behaviour to integrate any UI library:
  - Plain Tailwind CSS (default)
  - Custom component libraries
  - Database-driven dynamic components
  - Any other component library

  ## Using the Macro

  Use `use MishkaGervaz.Behaviours.UIAdapter` to get default implementations
  that delegate to Tailwind. Override only the components you need:

      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter

        # Override specific components - compile time check!
        if Code.ensure_loaded?(MyAppWeb.Components.Button) do
          def button(assigns), do: MyAppWeb.Components.Button.button(assigns)
        end

        # Everything else uses Tailwind defaults
      end

  ## With Components Module

  Pass your components module to auto-generate overrides:

      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components

        # Auto-generates overrides for any function that exists in MyAppWeb.Components
      end

  ## With Custom Fallback

  Specify a different fallback module instead of Tailwind:

      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          fallback: MyAppWeb.Components.Base,
          components: MyAppWeb.Components.Custom
      end

  Then use in DSL:

      presentation do
        ui_adapter MyAppWeb.UIAdapter
      end
  """

  @doc "Render a text input"
  @callback text_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a select dropdown"
  @callback select(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a multi-select with search support"
  @callback multi_select(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a single-select with search support"
  @callback search_select(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a single-select with paginated load-more (no search input)"
  @callback load_more_select(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a checkbox"
  @callback checkbox(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a date input"
  @callback date_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a datetime input"
  @callback datetime_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a number input"
  @callback number_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a button"
  @callback button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render an icon"
  @callback icon(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a badge/tag"
  @callback badge(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a loading spinner"
  @callback spinner(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render empty state"
  @callback empty_state(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render error state"
  @callback error_state(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a date range container"
  @callback date_range_container(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a navigation link"
  @callback nav_link(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render table wrapper"
  @callback table(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render table header row"
  @callback table_header(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a table header cell"
  @callback th(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a table row"
  @callback tr(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a table cell"
  @callback td(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a dropdown menu"
  @callback dropdown(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render empty cell value (nil/missing data)"
  @callback cell_empty(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render text cell value"
  @callback cell_text(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render number cell value"
  @callback cell_number(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render date cell value"
  @callback cell_date(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render datetime cell value"
  @callback cell_datetime(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render code/monospace cell value"
  @callback cell_code(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render array/list container"
  @callback cell_array(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render filter reset/clear button"
  @callback filter_reset_button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render archive status toggle"
  @callback archive_toggle(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render bulk actions bar container"
  @callback bulk_action_bar(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render individual bulk action button"
  @callback bulk_action_button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render pagination container with page info"
  @callback pagination_container(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render pagination nav button (prev/next/first/last)"
  @callback pagination_nav_button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render pagination page number button"
  @callback pagination_page_button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render loading state"
  @callback loading_state(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render template switcher container with buttons"
  @callback template_switcher(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render template switcher button"
  @callback template_switcher_button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render the main form wrapper (phx-change, phx-submit)"
  @callback form_container(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a field wrapper with label, input, and error display"
  @callback field_wrapper(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a collapsible group of fields"
  @callback field_group(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render wizard/tabs step progress indicator"
  @callback step_indicator(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render wizard prev/next/submit navigation controls"
  @callback step_navigation(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a drag-drop file upload zone"
  @callback upload_dropzone(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a file preview thumbnail"
  @callback upload_preview(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render an upload progress bar"
  @callback upload_progress(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a boolean toggle switch"
  @callback toggle_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a range slider input"
  @callback range_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a multi-line text input"
  @callback textarea(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a JSON editor (textarea with formatting)"
  @callback json_editor(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a container for nested form fields"
  @callback nested_fields(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a container for array-of-maps fields"
  @callback array_fields(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a field error message display"
  @callback field_error(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a styled file input (non-dropzone) upload control"
  @callback upload_file_input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render an existing file card with remove button (for edit mode)"
  @callback upload_existing_file(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @optional_callbacks [
    # Table-only optional (23)
    template_switcher: 1,
    multi_select: 1,
    search_select: 1,
    dropdown: 1,
    empty_state: 1,
    error_state: 1,
    cell_empty: 1,
    cell_text: 1,
    cell_number: 1,
    cell_date: 1,
    cell_datetime: 1,
    cell_code: 1,
    cell_array: 1,
    filter_reset_button: 1,
    archive_toggle: 1,
    bulk_action_bar: 1,
    bulk_action_button: 1,
    pagination_container: 1,
    pagination_nav_button: 1,
    pagination_page_button: 1,
    loading_state: 1,
    template_switcher_button: 1,
    date_range_container: 1,
    nav_link: 1,
    table: 1,
    table_header: 1,
    th: 1,
    tr: 1,
    td: 1,
    # Form-only optional (15)
    form_container: 1,
    field_wrapper: 1,
    field_group: 1,
    step_indicator: 1,
    step_navigation: 1,
    upload_dropzone: 1,
    upload_preview: 1,
    upload_progress: 1,
    toggle_input: 1,
    range_input: 1,
    textarea: 1,
    json_editor: 1,
    nested_fields: 1,
    array_fields: 1,
    field_error: 1,
    upload_file_input: 1,
    upload_existing_file: 1
  ]

  @component_functions [
    # Shared
    :text_input,
    :select,
    :multi_select,
    :search_select,
    :load_more_select,
    :checkbox,
    :date_input,
    :datetime_input,
    :number_input,
    :button,
    :icon,
    :badge,
    :spinner,
    :empty_state,
    :error_state,
    # Table-only
    :date_range_container,
    :nav_link,
    :table,
    :table_header,
    :th,
    :tr,
    :td,
    :dropdown,
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
    # Form-only
    :form_container,
    :field_wrapper,
    :field_group,
    :step_indicator,
    :step_navigation,
    :upload_dropzone,
    :upload_preview,
    :upload_progress,
    :toggle_input,
    :range_input,
    :textarea,
    :json_editor,
    :nested_fields,
    :array_fields,
    :field_error,
    :upload_file_input,
    :upload_existing_file
  ]

  @doc """
  Use this module to get default implementations for all callbacks.

  ## Options

    * `:fallback` - Fallback module for defaults. Defaults to `MishkaGervaz.UIAdapters.Tailwind`
    * `:components` - Components module to auto-generate overrides from. Optional.
    * `:nested_components` - If true, uses nested module style (e.g., `Components.Button.button/1`).
      If false, uses flat style (e.g., `Components.button/1`). Defaults to false.
    * `:module_prefix` - Prefix added to module names (e.g., `"Mishka"` -> `Components.MishkaButton`).
    * `:component_prefix` - Prefix added to function names (e.g., `"mc_"` -> `mc_button/1`).

  ## Examples

      # Simple usage - all defaults from Tailwind
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter
      end

      # With flat components module (Components.button/1)
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components
      end

      # With nested components style (Components.Button.button/1)
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          nested_components: true
      end

      # With module prefix (Components.MishkaButton.button/1)
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          nested_components: true,
          module_prefix: "Mishka"
      end

      # With component prefix (Components.Button.mc_button/1)
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          nested_components: true,
          component_prefix: "mc_"
      end

      # With both prefixes (Components.MishkaButton.mc_button/1)
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          nested_components: true,
          module_prefix: "Mishka",
          component_prefix: "mc_"
      end
  """
  defmacro __using__(opts \\ []) do
    fallback = Keyword.get(opts, :fallback, MishkaGervaz.UIAdapters.Tailwind)
    components = Keyword.get(opts, :components)
    nested_components = Keyword.get(opts, :nested_components, false)
    module_prefix = Keyword.get(opts, :module_prefix)
    component_prefix = Keyword.get(opts, :component_prefix)

    default_delegates =
      for func <- @component_functions do
        quote do
          defdelegate unquote(func)(assigns), to: unquote(fallback)
        end
      end

    component_overrides =
      if components do
        if nested_components do
          for func <- @component_functions do
            mod_name =
              func
              |> Atom.to_string()
              |> Macro.camelize()
              |> String.to_atom()

            prefixed_mod_name =
              if module_prefix do
                String.to_atom("#{module_prefix}#{mod_name}")
              else
                mod_name
              end

            full_module = Module.concat(components, prefixed_mod_name)

            target_func =
              if component_prefix do
                String.to_atom("#{component_prefix}#{func}")
              else
                func
              end

            quote do
              if Code.ensure_loaded?(unquote(full_module)) and
                   function_exported?(unquote(full_module), unquote(target_func), 1) do
                def unquote(func)(assigns), do: unquote(full_module).unquote(target_func)(assigns)
              end
            end
          end
        else
          for func <- @component_functions do
            target_func =
              if component_prefix do
                String.to_atom("#{component_prefix}#{func}")
              else
                func
              end

            quote do
              if Code.ensure_loaded?(unquote(components)) and
                   function_exported?(unquote(components), unquote(target_func), 1) do
                def unquote(func)(assigns), do: unquote(components).unquote(target_func)(assigns)
              end
            end
          end
        end
      else
        []
      end

    quote do
      @behaviour MishkaGervaz.Behaviours.UIAdapter
      use Phoenix.Component

      unquote_splicing(default_delegates)

      defoverridable unquote(Enum.map(@component_functions, &{&1, 1}))

      unquote_splicing(component_overrides)
    end
  end
end
