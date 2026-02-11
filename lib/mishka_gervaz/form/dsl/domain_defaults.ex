defmodule MishkaGervaz.Form.Dsl.DomainDefaults do
  @moduledoc """
  DSL section for domain-level form configuration.

  These form defaults are inherited by all resources in the domain
  that use `MishkaGervaz.Resource`.

  Used by `MishkaGervaz.Domain` extension.
  """

  @actions_schema [
    create: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_create, :create},
      doc: "Default create action or {master_action, tenant_action}."
    ],
    update: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_update, :update},
      doc: "Default update action or {master_action, tenant_action}."
    ],
    read: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_get, :read},
      doc: "Default read/get action or {master_action, tenant_action}."
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
