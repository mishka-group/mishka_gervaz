defmodule MishkaGervaz.Form.Dsl.Presentation do
  @moduledoc """
  Presentation section DSL definition for form configuration.

  Defines UI adapter, templates, and theming configuration.

  Structure mirrors the table DSL:
  - `presentation > theme` for form theming
  """

  @theme_schema [
    form_class: [
      type: :string,
      doc: "Form element CSS classes."
    ],
    field_class: [
      type: :string,
      doc: "Default field CSS classes."
    ],
    label_class: [
      type: :string,
      doc: "Default label CSS classes."
    ],
    error_class: [
      type: :string,
      doc: "Error message CSS classes."
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

  @presentation_schema [
    debounce: [
      type: :integer,
      doc:
        "Default debounce milliseconds for all fields. Overridden per-field via `ui do debounce end`."
    ],
    template: [
      type: :atom,
      doc: "Template module for form layout."
    ],
    ui_adapter: [
      type: :atom,
      doc: "UI adapter module for rendering components."
    ],
    ui_adapter_opts: [
      type: :keyword_list,
      default: [],
      doc: "Options for UI adapter configuration."
    ],
    features: [
      type:
        {:or,
         [
           {:in, [:all]},
           {:list,
            {:in,
             [
               :validation,
               :uploads,
               :groups,
               :wizard,
               :autosave,
               :inline_errors
             ]}}
         ]},
      default: :all,
      doc: "Features to enable for this form."
    ]
  ]

  @doc false
  def schema, do: @presentation_schema

  @doc """
  Returns the presentation section definition with nested theme section.
  """
  def section do
    %Spark.Dsl.Section{
      name: :presentation,
      describe: "UI adapter and theming configuration.",
      schema: @presentation_schema,
      sections: [theme_section()]
    }
  end
end
