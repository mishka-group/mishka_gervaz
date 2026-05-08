defmodule MishkaGervaz.Behaviours.UIAdapter do
  @moduledoc """
  Behaviour for UI component adapters.

  Implement this behaviour to integrate any UI library:

  - Plain Tailwind CSS (default, `MishkaGervaz.UIAdapters.Tailwind`)
  - A custom component library
  - Database-driven dynamic components
  - Anything else with the same per-component shape

  ## Using the macro

  `use MishkaGervaz.Behaviours.UIAdapter` provides default implementations
  that delegate to a fallback module (Tailwind by default). Override only
  the components you need:

      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter

        # Override specific components — everything else uses Tailwind defaults.
        def button(assigns), do: MyAppWeb.Components.Button.button(assigns)
      end

  ## With a components module

  Pass your components module to auto-generate overrides for any function
  it exports:

      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components
      end

  ## With a custom fallback

  Use a different fallback module instead of Tailwind:

      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          fallback: MyAppWeb.Components.Base,
          components: MyAppWeb.Components.Custom
      end

  ## DSL usage

      presentation do
        ui_adapter MyAppWeb.UIAdapter
      end
  """

  @typedoc "Phoenix LiveView assigns map passed to every component function."
  @type assigns :: map()

  @typedoc "A `{function_name, docstring}` pair."
  @type component :: {atom(), String.t()}

  # Single source of truth for all component callbacks. Every entry produces
  # a `@callback`, an entry in `@component_functions` (drives the
  # `defdelegate` defaults in `__using__`), and an entry in
  # `@optional_callbacks`. To add a new component, add ONE line here.
  @components [
    # ----- Inputs -----------------------------------------------------------
    {:text_input, "Render a text input"},
    {:select, "Render a select dropdown"},
    {:multi_select, "Render a multi-select with search support"},
    {:search_select, "Render a single-select with search support"},
    {:load_more_select, "Render a single-select with paginated load-more (no search input)"},
    {:checkbox, "Render a checkbox"},
    {:date_input, "Render a date input"},
    {:datetime_input, "Render a datetime input"},
    {:number_input, "Render a number input"},
    {:textarea, "Render a multi-line text input"},
    {:json_editor, "Render a JSON editor (textarea with formatting)"},
    {:toggle_input, "Render a boolean toggle switch"},
    {:range_input, "Render a range slider input"},
    {:string_list_input, "Render a dynamic string list input with add/remove buttons"},
    {:password_input, "Render a password input (masked text entry)"},
    {:combobox, "Render a combobox (text input with dropdown suggestions)"},

    # ----- Actions and display ---------------------------------------------
    {:button, "Render a button"},
    {:icon, "Render an icon"},
    {:badge, "Render a badge/tag"},
    {:spinner, "Render a loading spinner"},
    {:nav_link, "Render a navigation link"},
    {:dropdown, "Render a dropdown menu"},

    # ----- State and status ------------------------------------------------
    {:empty_state, "Render empty state"},
    {:error_state, "Render error state"},
    {:loading_state, "Render loading state"},
    {:alert, "Render a static alert/notice (info/warning/error/success/neutral)"},

    # ----- Table -----------------------------------------------------------
    {:table, "Render table wrapper"},
    {:table_header, "Render table header row"},
    {:th, "Render a table header cell"},
    {:tr, "Render a table row"},
    {:td, "Render a table cell"},
    {:date_range_container, "Render a date range container"},
    {:cell_empty, "Render empty cell value (nil/missing data)"},
    {:cell_text, "Render text cell value"},
    {:cell_number, "Render number cell value"},
    {:cell_date, "Render date cell value"},
    {:cell_datetime, "Render datetime cell value"},
    {:cell_code, "Render code/monospace cell value"},
    {:cell_array, "Render array/list container"},
    {:filter_reset_button, "Render filter reset/clear button"},
    {:archive_toggle, "Render archive status toggle"},
    {:bulk_action_bar, "Render bulk actions bar container"},
    {:bulk_action_button, "Render individual bulk action button"},
    {:pagination_container, "Render pagination container with page info"},
    {:pagination_nav_button, "Render pagination nav button (prev/next/first/last)"},
    {:pagination_page_button, "Render pagination page number button"},
    {:template_switcher, "Render template switcher container with buttons"},
    {:template_switcher_button, "Render template switcher button"},

    # ----- Form ------------------------------------------------------------
    {:form_container, "Render the main form wrapper (phx-change, phx-submit)"},
    {:form_header, "Render a form header (title + description)"},
    {:form_footer, "Render a form footer (static content below the submit row)"},
    {:field_wrapper, "Render a field wrapper with label, input, and error display"},
    {:field_group, "Render a collapsible group of fields"},
    {:field_error, "Render a field error message display"},
    {:step_indicator, "Render wizard/tabs step progress indicator"},
    {:step_navigation, "Render wizard prev/next/submit navigation controls"},
    {:upload_dropzone, "Render a drag-drop file upload zone"},
    {:upload_preview, "Render a file preview thumbnail"},
    {:upload_progress, "Render an upload progress bar"},
    {:upload_file_input, "Render a styled file input (non-dropzone) upload control"},
    {:upload_existing_file, "Render an existing file card with remove button (for edit mode)"},
    {:nested_fields, "Render a container for nested form fields"},
    {:array_fields, "Render a container for array-of-maps fields"}
  ]

  @component_functions Enum.map(@components, &elem(&1, 0))

  for {name, doc} <- @components do
    @doc doc
    @callback unquote(name)(assigns()) :: Phoenix.LiveView.Rendered.t()
  end

  # Every callback ships with a default implementation via `use`, so all of
  # them are effectively optional — hand-rolled implementers can pick the
  # subset they want without compile warnings.
  @optional_callbacks Enum.map(@component_functions, &{&1, 1})

  @doc """
  The list of every component function name on the behaviour. Useful for
  introspection and for tests that want to assert all functions are wired.
  """
  @spec component_functions() :: [atom()]
  def component_functions, do: @component_functions

  @doc """
  Resolves the `{module, function}` target a generated override should call,
  given the consuming module's `:components`, `:nested_components`,
  `:module_prefix`, and `:component_prefix` options.

  Public so the macro can call it; also useful for testing the routing
  logic directly without having to build a full adapter.
  """
  @spec resolve_target(atom(), module(), boolean(), String.t() | nil, String.t() | nil) ::
          {module(), atom()}
  def resolve_target(func, components, nested?, module_prefix, component_prefix) do
    {target_module(func, components, nested?, module_prefix),
     target_function(func, component_prefix)}
  end

  defp target_function(func, nil), do: func
  defp target_function(func, prefix), do: String.to_atom("#{prefix}#{func}")

  defp target_module(_func, components, false, _module_prefix), do: components

  defp target_module(func, components, true, module_prefix) do
    submodule =
      func
      |> Atom.to_string()
      |> Macro.camelize()
      |> then(&"#{module_prefix || ""}#{&1}")
      |> String.to_atom()

    Module.concat(components, submodule)
  end

  @doc """
  Sets up an adapter that delegates every component to a fallback module,
  and optionally overrides specific components from a `:components` module.

  ## Options

    * `:fallback` — module providing the default implementations.
      Defaults to `MishkaGervaz.UIAdapters.Tailwind`.

    * `:components` — module to source overrides from. Each component
      function is wired only when the target module is loaded **and**
      exports the corresponding 1-arity function.

    * `:nested_components` — when `true`, look for each component under a
      submodule (e.g. `Components.Button.button/1`). When `false` (default),
      the components module is flat (e.g. `Components.button/1`).

    * `:module_prefix` — a string prepended to each submodule name when
      `nested_components: true`. Example: `"Mishka"` makes the macro look
      under `Components.MishkaButton.button/1`.

    * `:component_prefix` — a string prepended to each function name.
      Example: `"mc_"` makes the macro look up `mc_button/1` on the target
      module.

  ## Examples

      # All defaults from Tailwind
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter
      end

      # Flat components module — Components.button/1
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components
      end

      # Nested style — Components.Button.button/1
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          nested_components: true
      end

      # Module prefix — Components.MishkaButton.button/1
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          nested_components: true,
          module_prefix: "Mishka"
      end

      # Function prefix — Components.mc_button/1
      defmodule MyAppWeb.UIAdapter do
        use MishkaGervaz.Behaviours.UIAdapter,
          components: MyAppWeb.Components,
          component_prefix: "mc_"
      end
  """
  defmacro __using__(opts \\ []) do
    fallback =
      opts
      |> Keyword.get(:fallback, MishkaGervaz.UIAdapters.Tailwind)
      |> Macro.expand(__CALLER__)

    components =
      case Keyword.get(opts, :components) do
        nil -> nil
        mod -> Macro.expand(mod, __CALLER__)
      end

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
        for func <- @component_functions do
          {target_mod, target_func} =
            __MODULE__.resolve_target(
              func,
              components,
              nested_components,
              module_prefix,
              component_prefix
            )

          quote do
            if Code.ensure_loaded?(unquote(target_mod)) and
                 function_exported?(unquote(target_mod), unquote(target_func), 1) do
              def unquote(func)(assigns), do: unquote(target_mod).unquote(target_func)(assigns)
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
