defmodule MishkaGervaz.Form.Dsl.Presentation do
  @moduledoc """
  Presentation section — UI adapter, template, features, and theming.

  Controls how the form renders: which `ui_adapter` supplies the
  per-component renderers (button, text_input, etc.), which `template`
  arranges them, what subset of `features` to enable, and the default
  theme classes used by every field/group/error slot.

  ## Example

      presentation do
        ui_adapter MyApp.UIAdapter
        template MishkaGervaz.Form.Templates.Standard
        features :all
        debounce 300

        theme do
          form_class "max-w-4xl"
          field_class "rounded-md"
          label_class "text-sm font-medium"
          error_class "text-red-600"
        end
      end

  ## Notable options

    * `ui_adapter` — module implementing
      `MishkaGervaz.Behaviours.UIAdapter`. Defaults to
      `MishkaGervaz.UIAdapters.Tailwind`.
    * `template` — module implementing the form template behaviour.
      Defaults to `MishkaGervaz.Form.Templates.Standard`.
    * `features` — `:all` (use everything the template supports) or an
      explicit list:
      `[:validation, :uploads, :groups, :wizard, :autosave, :inline_errors]`.
    * `debounce` — global default phx-debounce in ms; overridable
      per field via `field :foo do ui do debounce 500 end end`.
    * `theme do …` — string-class slots (`form_class`, `field_class`,
      `label_class`, `error_class`); template-specific options go in
      `extra: %{…}`.
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
