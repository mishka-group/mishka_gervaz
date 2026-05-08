defmodule MishkaGervaz.Form.Dsl.DomainDefaults do
  @moduledoc """
  Domain-level form defaults inherited by every resource that uses
  `MishkaGervaz.Resource` under this domain.

  Used by the `MishkaGervaz.Domain` extension. Resource-level
  configuration takes priority on a per-key basis; missing keys fall
  back to the domain defaults. The `submit` entity is the same one
  exposed at the resource level (`MishkaGervaz.Form.Dsl.Submit`) — both
  layers accept identical syntax, and submit inheritance is per-button,
  not whole-block.

  ## Example

      defmodule MyApp.Domain do
        use Ash.Domain, extensions: [MishkaGervaz.Domain]

        mishka_gervaz do
          form do
            actor_key :current_user
            master_check fn user -> user && user.role == :admin end
            ui_adapter MishkaGervaz.UIAdapters.Tailwind
            template MishkaGervaz.Form.Templates.Standard
            features :all

            actions do
              create {:master_create, :create}
              update {:master_update, :update}
              read   {:master_get, :read}
            end

            layout do
              responsive true
            end

            submit do
              create label: "Save"
              update label: "Save Changes"
              cancel label: "Cancel"
              position :bottom
            end
          end
        end
      end

  ## Sub-sections and entity

    * `actions` — same shape as the resource-level `source.actions`.
    * `theme` — default theme classes inherited by every form.
    * `layout` — defaults for `navigation`, `persistence`, `columns`,
      `responsive`.
    * `submit` — domain-wide default buttons. Resource buttons override
      per-button, not as a whole block.

  Read accessors live on `MishkaGervaz.Domain.Info.Form`.
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
