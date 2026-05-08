defmodule MishkaGervaz.Form.Behaviours.Template do
  @moduledoc """
  Behaviour for form layout templates.

  Templates define **how the form is structured**:

    - Standard — single-page form with groups
    - Wizard   — multi-step form with progress indicator
    - Tabs     — tabbed form layout

  Templates pair with UI adapters along orthogonal axes:

    - **Template**   — *where* things go (structure / layout)
    - **UIAdapter**  — *how* things look (styling / CSS)

  ## Two ways to implement

  Bare behaviour — implement every required callback yourself. The default
  template `MishkaGervaz.Form.Templates.Standard` follows this path:

      defmodule MyApp.Form.Templates.Custom do
        @behaviour MishkaGervaz.Form.Behaviours.Template
        use Phoenix.Component

        @impl true
        def name, do: :custom

        @impl true
        def label, do: "Custom Form"

        @impl true
        def icon, do: "hero-document-text"

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <div class="my-custom-form">...</div>
          \"\"\"
        end

        # render_loading/1, render_field/1, render_group/1,
        # render_step_indicator/1 must be implemented or `use`-d below.
      end

  Or `use` this module to inherit `Standard`'s implementations of the
  optional callbacks (overridable). Most custom templates only need to
  override `render/1`:

      defmodule MyApp.Form.Templates.Sidebar do
        use MishkaGervaz.Form.Behaviours.Template

        @impl true
        def name,  do: :sidebar
        @impl true
        def label, do: "Sidebar"
        @impl true
        def icon,  do: "hero-bars-3"

        @impl true
        def render(assigns), do: ~H"<aside>...</aside>"

        # render_loading, render_field, render_group, render_step_indicator
        # delegate to Standard. Override any of them as needed.
      end

  See `MishkaGervaz.Form.Templates.Standard`,
  `MishkaGervaz.Form.Behaviours.FieldType`, and
  `MishkaGervaz.Behaviours.UIAdapter`.
  """

  @typedoc "Phoenix LiveView assigns map."
  @type assigns :: map()

  @typedoc "Result of a Phoenix render."
  @type rendered :: Phoenix.LiveView.Rendered.t()

  @doc "Unique template identifier atom."
  @callback name() :: atom()

  @doc "Human-readable label for UI display."
  @callback label() :: String.t()

  @doc "Icon identifier."
  @callback icon() :: String.t()

  @doc """
  Render the complete form.

  Assigns include:

    - `@static`  — static form configuration (fields, groups, steps,
      ui_adapter, …)
    - `@state`   — dynamic form state (form, errors, current_step, …)
    - `@myself`  — `LiveComponent` reference for targeting events
  """
  @callback render(assigns()) :: rendered()

  @doc "Render the loading state while the form is being initialized."
  @callback render_loading(assigns()) :: rendered()

  @doc "Render a single field by dispatching to its type."
  @callback render_field(assigns()) :: rendered()

  @doc "Render a group of fields."
  @callback render_group(assigns()) :: rendered()

  @doc "Render the step indicator for wizard / tabs mode."
  @callback render_step_indicator(assigns()) :: rendered()

  @optional_callbacks [
    render_loading: 1,
    render_field: 1,
    render_group: 1,
    render_step_indicator: 1
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Form.Behaviours.Template
      use Phoenix.Component

      def render_loading(assigns) do
        MishkaGervaz.Form.Templates.Standard.render_loading(assigns)
      end

      def render_field(assigns) do
        MishkaGervaz.Form.Templates.Standard.render_field(assigns)
      end

      def render_group(assigns) do
        MishkaGervaz.Form.Templates.Standard.render_group(assigns)
      end

      def render_step_indicator(assigns) do
        MishkaGervaz.Form.Templates.Standard.render_step_indicator(assigns)
      end

      defoverridable render_loading: 1,
                     render_field: 1,
                     render_group: 1,
                     render_step_indicator: 1
    end
  end
end
