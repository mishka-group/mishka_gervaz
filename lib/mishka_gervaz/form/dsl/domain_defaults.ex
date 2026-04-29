defmodule MishkaGervaz.Form.Dsl.DomainDefaults do
  @moduledoc """
  DSL section for domain-level form configuration.

  These form defaults are inherited by all resources in the domain
  that use `MishkaGervaz.Resource`.

  Used by `MishkaGervaz.Domain` extension.

  Domain `submit` mirrors the resource `submit` DSL — the same entity is
  reused so both layers accept identical syntax. Resource-level configuration
  takes priority on a per-button basis; missing buttons fall back to the
  domain configuration.
  """

  alias MishkaGervaz.Form.Dsl.Submit, as: SubmitDsl

  @actions_schema [
    create: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc:
        "Default create action. Atom (used for both master and tenant) or tuple " <>
          "`{master_action, tenant_action}`. Inherited by all form resources in the domain."
    ],
    update: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc:
        "Default update action. Atom or tuple `{master_action, tenant_action}`. " <>
          "Inherited by all form resources in the domain."
    ],
    read: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc:
        "Default read/get action. Atom or tuple `{master_action, tenant_action}`. " <>
          "Inherited by all form resources in the domain."
    ]
  ]

  @theme_schema [
    form_class: [
      type: :string,
      doc: "Default form CSS classes."
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
      doc: "Default error message CSS classes."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Default extra theme options."
    ]
  ]

  @layout_schema [
    navigation: [
      type: {:in, [:sequential, :free]},
      default: :sequential,
      doc: "Default wizard navigation mode."
    ],
    persistence: [
      type: {:in, [:none, :ets, :client_token]},
      default: :none,
      doc: "Default wizard step persistence."
    ],
    columns: [
      type: :pos_integer,
      default: 1,
      doc: "Default number of form columns."
    ],
    responsive: [
      type: :boolean,
      default: true,
      doc: "Default responsive layout behaviour."
    ]
  ]

  @schema [
    ui_adapter: [
      type: :atom,
      doc: "Default form UI adapter module."
    ],
    ui_adapter_opts: [
      type: :keyword_list,
      default: [],
      doc: "Default form UI adapter options."
    ],
    actor_key: [
      type: :atom,
      default: :current_user,
      doc: "Default assign key for current user."
    ],
    master_check: [
      type: {:fun, 1},
      doc: "Default function to check if user is master. `fn user -> boolean`."
    ],
    template: [
      type: :atom,
      doc: "Default template module for form layout."
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
      doc: "Default features to enable for forms."
    ]
  ]

  def section do
    %Spark.Dsl.Section{
      name: :form,
      describe: "Form configuration inherited by all resources in this domain.",
      schema: @schema,
      sections: [
        actions_section(),
        theme_section(),
        layout_section()
      ],
      entities: [
        SubmitDsl.entity()
      ]
    }
  end

  defp actions_section do
    %Spark.Dsl.Section{
      name: :actions,
      describe: "Default form action mapping.",
      schema: @actions_schema
    }
  end

  defp theme_section do
    %Spark.Dsl.Section{
      name: :theme,
      describe: "Default form theme configuration.",
      schema: @theme_schema
    }
  end

  defp layout_section do
    %Spark.Dsl.Section{
      name: :layout,
      describe: "Default form layout configuration.",
      schema: @layout_schema
    }
  end
end
