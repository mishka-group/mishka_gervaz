defmodule MishkaGervaz.Table.Dsl.Presentation do
  @moduledoc """
  Presentation section DSL definition for table configuration.

  Defines UI adapter, templates, theming, and responsive configuration.

  ## Templates vs UI Adapters

  - **Template**: Defines the layout structure (Table, MediaGallery)
  - **UIAdapter**: Defines the styling (Tailwind, Mishka Chelekom, Bootstrap, Custom)

  Templates control WHERE things go (rows/columns vs cards vs thumbnails).
  UI Adapters control HOW things look (colors, spacing, component styles).
  """

  @theme_schema [
    header_class: [
      type: :string,
      doc: "Header row CSS classes."
    ],
    row_class: [
      type: :string,
      doc: "Data row CSS classes."
    ],
    border_class: [
      type: :string,
      doc: "Border CSS classes."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Template-specific theming options."
    ]
  ]

  defp theme_section do
    %Spark.Dsl.Section{
      name: :theme,
      describe: "Theme configuration.",
      schema: @theme_schema
    }
  end

  @responsive_schema [
    hide_on_mobile: [
      type: {:list, :atom},
      default: [],
      doc: "Columns to hide on mobile."
    ],
    hide_on_tablet: [
      type: {:list, :atom},
      default: [],
      doc: "Columns to hide on tablet."
    ],
    mobile_layout: [
      type: {:in, [:cards, :stacked]},
      doc: "Layout mode on mobile."
    ]
  ]

  defp responsive_section do
    %Spark.Dsl.Section{
      name: :responsive,
      describe: "Responsive configuration.",
      schema: @responsive_schema
    }
  end

  @presentation_schema [
    filter_mode: [
      type: {:in, [:inline, :sidebar, :modal, :drawer]},
      default: :inline,
      doc: "Filter display mode: :inline (default), :sidebar, :modal, or :drawer."
    ],
    template: [
      type: {:or, [:atom, {:behaviour, MishkaGervaz.Table.Behaviours.Template}]},
      default: MishkaGervaz.Table.Templates.Table,
      doc: """
      Default template module for layout structure.
      Built-in templates:
      - `MishkaGervaz.Table.Templates.Table` - Traditional rows/columns (default)
      - `MishkaGervaz.Table.Templates.MediaGallery` - Image/file gallery
      """
    ],
    switchable_templates: [
      type: {:list, {:or, [:atom, {:behaviour, MishkaGervaz.Table.Behaviours.Template}]}},
      default: [],
      doc: """
      List of template modules users can switch between at runtime.
      If empty, template switching is disabled.
      Example: [MishkaGervaz.Table.Templates.Table, MishkaGervaz.Table.Templates.MediaGallery]
      """
    ],
    template_options: [
      type: :keyword_list,
      default: [],
      doc: """
      Options passed to the template.
      Common options vary by template:
      - Table: [:striped, :bordered, :compact, :hoverable]
      - MediaGallery: [:thumbnail_size, :aspect_ratio, :columns]
      """
    ],
    features: [
      type:
        {:or,
         [
           {:in, [:all]},
           {:list,
            {:in,
             [
               :sort,
               :filter,
               :select,
               :bulk_actions,
               :paginate,
               :export,
               :expand,
               :reorder,
               :inline_edit
             ]}}
         ]},
      default: :all,
      doc: """
      Features to enable for this table.

      Can be `:all` (default - uses template's features) or a list of specific features.

      Available features:
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

          # Use all template features (default)
          features :all

          # Only specific features
          features [:filter, :paginate]

          # Disable all features
          features []
      """
    ],
    ui_adapter: [
      type: {:or, [:atom, {:behaviour, MishkaGervaz.Behaviours.UIAdapter}]},
      default: MishkaGervaz.UIAdapters.Tailwind,
      doc: """
      UI adapter module for rendering components.

      Built-in adapters:
      - `MishkaGervaz.UIAdapters.Tailwind` - Plain Tailwind CSS (default)

      Create custom adapter with `use MishkaGervaz.Behaviours.UIAdapter`:

          defmodule MyAppWeb.UIAdapter do
            use MishkaGervaz.Behaviours.UIAdapter,
              components: MyAppWeb.Components  # Auto-override from your components

            # Or manually override specific functions:
            # def button(assigns), do: MyAppWeb.Components.Button.button(assigns)
          end

      Options for `use`:
      - `:fallback` - Fallback module (default: Tailwind)
      - `:components` - Module to auto-generate overrides from
      """
    ],
    ui_adapter_opts: [
      type: :keyword_list,
      default: [],
      doc: """
      Options for UI adapter configuration.

      ## Available Options

        * `:component_module` - Your components module (e.g., `MyAppWeb.Components`).
          When specified, generates a dynamic adapter at compile time that uses
          your components with Tailwind as fallback.

        * `:fallback` - Fallback adapter module. Defaults to `MishkaGervaz.UIAdapters.Tailwind`.

        * `:nested_components` - If true, uses nested module pattern (e.g., `Components.Button.button/1`).
          Automatically set to true when Chelekom adapter is selected.

        * `:module_prefix` - Prefix for module names (e.g., `"Mishka"` → `Components.MishkaButton`).

        * `:component_prefix` - Prefix for function names (e.g., `"mc_"` → `mc_button/1`).

      ## Examples

          # Basic Chelekom usage
          presentation do
            ui_adapter MishkaGervaz.Table.UIAdapters.Chelekom
            ui_adapter_opts component_module: MyAppWeb.Components
          end
          # Calls: MyAppWeb.Components.Button.button/1

          # With module prefix
          presentation do
            ui_adapter MishkaGervaz.Table.UIAdapters.Chelekom
            ui_adapter_opts component_module: MyAppWeb.Components, module_prefix: "Mishka"
          end
          # Calls: MyAppWeb.Components.MishkaButton.button/1

          # With component prefix
          presentation do
            ui_adapter MishkaGervaz.Table.UIAdapters.Chelekom
            ui_adapter_opts component_module: MyAppWeb.Components, component_prefix: "mc_"
          end
          # Calls: MyAppWeb.Components.Button.mc_button/1

          # With both prefixes
          presentation do
            ui_adapter MishkaGervaz.Table.UIAdapters.Chelekom
            ui_adapter_opts component_module: MyAppWeb.Components,
                            module_prefix: "Mishka",
                            component_prefix: "mc_"
          end
          # Calls: MyAppWeb.Components.MishkaButton.mc_button/1

      This auto-generates an adapter module `YourResource.GervazUIAdapter` that:
      - Delegates to your Chelekom components if they exist
      - Falls back to Tailwind for any missing components
      - All resolved at compile time with zero runtime overhead
      """
    ]
  ]

  @doc false
  def schema, do: @presentation_schema

  @doc """
  Returns the presentation section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :presentation,
      describe: "UI adapter and theming configuration.",
      schema: @presentation_schema,
      sections: [theme_section(), responsive_section()]
    }
  end
end
