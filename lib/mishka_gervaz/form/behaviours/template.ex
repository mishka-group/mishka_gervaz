defmodule MishkaGervaz.Form.Behaviours.Template do
  @moduledoc """
  Behaviour for form layout templates.

  Templates define HOW the form is structured and arranged:
  - Standard: Single-page form with groups
  - Wizard: Multi-step form with progress indicator
  - Tabs: Tabbed form layout

  Templates work together with UIAdapters:
  - Template = WHERE things go (structure/layout)
  - UIAdapter = HOW things look (styling/CSS)

  ## Creating a Custom Template

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
          <div class="my-custom-form">
            ...
          </div>
          \"\"\"
        end
      end
  """

  @type assigns :: map()
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
  - `@static` - Static form configuration (fields, groups, steps, ui_adapter, etc.)
  - `@state` - Dynamic form state (form, errors, current_step, etc.)
  - `@myself` - LiveComponent reference for targeting events
  """
  @callback render(assigns()) :: rendered()

  @doc "Render the loading state while form is being initialized."
  @callback render_loading(assigns()) :: rendered()

  @doc "Render a single field by dispatching to its type."
  @callback render_field(assigns()) :: rendered()

  @doc "Render a group of fields."
  @callback render_group(assigns()) :: rendered()

  @doc "Render the step indicator for wizard/tabs mode."
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
