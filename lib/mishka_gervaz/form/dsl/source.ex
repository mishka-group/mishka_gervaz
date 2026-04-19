defmodule MishkaGervaz.Form.Dsl.Source do
  @moduledoc """
  Source section DSL definition for form configuration.

  Defines action mapping and preloading configuration for form data operations.

  Structure mirrors the table DSL pattern:
  - `source > actions` for create/update/read action mapping
  - `source > preload` for three-tier preload configuration
  """

  @actions_schema [
    create: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_create, :create},
      doc: "Create action. Atom or tuple `{master_action, tenant_action}`."
    ],
    update: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_update, :update},
      doc: "Update action. Atom or tuple `{master_action, tenant_action}`."
    ],
    read: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_get, :read},
      doc: "Read/get action. Atom or tuple `{master_action, tenant_action}`."
    ]
  ]

  defp actions_section do
    %Spark.Dsl.Section{
      name: :actions,
      describe: "Action mapping configuration for master/tenant actions.",
      schema: @actions_schema
    }
  end

  @preload_item_type {:or, [:atom, {:tuple, [:atom, :atom]}]}

  @preload_schema [
    always: [
      type: {:list, @preload_item_type},
      default: [],
      doc: """
      Always preload these relationships.

      Supports atoms or `{source, alias}` tuples:
      - `:category` - preload `:category` relationship
      - `{:category, :cat}` or `category: :cat` - preload `:category`, alias as `:cat`

      > ### Pagination Warning {: .warning}
      >
      > The relationship's read action must NOT have `pagination required?: true`.
      > Preloads do not pass pagination params, so required pagination will cause
      > `LimitRequired` errors at runtime. Use `required?: false` on the action:
      >
      >     read :my_action do
      >       pagination offset?: true, required?: false, default_limit: 20
      >     end
      """
    ],
    master: [
      type: {:list, @preload_item_type},
      default: [],
      doc: """
      Additional preloads for master users.

      Supports atoms or `{source, alias}` tuples.
      See `always` for pagination requirements.
      """
    ],
    tenant: [
      type: {:list, @preload_item_type},
      default: [],
      doc: """
      Additional preloads for tenant users.

      Supports atoms or `{source, alias}` tuples.
      See `always` for pagination requirements.
      """
    ]
  ]

  defp preload_section do
    %Spark.Dsl.Section{
      name: :preload,
      describe: "Preload configuration for relationships.",
      schema: @preload_schema
    }
  end

  @source_schema [
    actor_key: [
      type: :atom,
      default: :current_user,
      doc: "Assigns key for current user."
    ],
    master_check: [
      type: {:fun, 1},
      doc: "Function returning true for master users. `fn user -> boolean`"
    ],
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Restrict all form modes to master users. Boolean or `fn state -> boolean end`."
    ]
  ]

  alias MishkaGervaz.Form.Entities.Access, as: AccessEntity

  defp access_entity do
    %Spark.Dsl.Entity{
      name: :access,
      describe: "Access control rule. Per-mode or global gate.",
      target: AccessEntity,
      args: [{:optional, :mode}, {:optional, :condition}],
      identifier: :mode,
      schema: AccessEntity.opt_schema(),
      transform: {AccessEntity, :transform, []}
    }
  end

  @doc false
  def schema, do: @source_schema

  @doc """
  Returns the source section definition with nested actions and preload sections.
  """
  def section do
    %Spark.Dsl.Section{
      name: :source,
      describe: "Data fetching, action mapping, and preloading configuration.",
      schema: @source_schema,
      sections: [
        actions_section(),
        preload_section()
      ],
      entities: [
        access_entity()
      ]
    }
  end
end
