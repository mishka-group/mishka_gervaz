defmodule MishkaGervaz.Table.Dsl.Source do
  @moduledoc """
  Source section DSL definition for table configuration.

  Defines data fetching, action mapping, preloading, and archive configuration.
  Tenant field is auto-detected from Ash multitenancy config.
  """

  @actions_schema [
    read: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc:
        "Read action. Atom (used for both master and tenant) or tuple `{master_action, tenant_action}`. " <>
          "Required either here or on the domain — compile fails otherwise."
    ],
    get: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc:
        "Get action. Atom or tuple `{master_action, tenant_action}`. " <>
          "Required either here or on the domain."
    ],
    destroy: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc:
        "Destroy action. Atom or tuple `{master_action, tenant_action}`. " <>
          "Required either here or on the domain."
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
      - `:site` - preload `:site` relationship
      - `{:site, :site_info}` or `site: :site_info` - preload `:site`, alias as `:site_info`
      """
    ],
    master: [
      type: {:list, @preload_item_type},
      default: [],
      doc: """
      Additional preloads for master users.

      Supports atoms or `{source, alias}` tuples:
      - `:layout` - preload `:layout` relationship
      - `{:layout, :page_layout}` or `layout: :page_layout` - preload `:layout`, alias as `:page_layout`
      """
    ],
    tenant: [
      type: {:list, @preload_item_type},
      default: [],
      doc: """
      Additional preloads for tenant users.

      Supports atoms or `{source, alias}` tuples:
      - `:tenant_layout` - preload `:tenant_layout` relationship
      - `{:tenant_layout, :layout}` or `tenant_layout: :layout` - preload `:tenant_layout`, alias as `:layout`

      This allows master/tenant to expose different relationships under the same alias key.
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

  @archive_schema [
    enabled: [
      type: :boolean,
      doc: "Enable archive support. Set `false` to disable without removing the block."
    ],
    restricted: [
      type: :boolean,
      doc:
        "Restrict archive UI to master users only. When `true`, tenant users cannot see archive toggle."
    ],
    visible: [
      type: {:or, [:boolean, {:mfa_or_fun, 1}]},
      doc:
        "Control archive toggle visibility. Boolean or `fn state -> boolean` for dynamic control."
    ],
    read_action: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Read archived action. Can be single atom or tuple `{master_action, tenant_action}`."
    ],
    get_action: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Get archived action. Can be single atom or tuple."
    ],
    restore_action: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Restore action. Can be single atom or tuple."
    ],
    destroy_action: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Permanent destroy action. Can be single atom or tuple."
    ]
  ]

  defp archive_section do
    %Spark.Dsl.Section{
      name: :archive,
      describe: "Archive configuration for soft-delete support.",
      schema: @archive_schema
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
    ]
  ]

  @doc false
  def schema, do: @source_schema

  @doc """
  Returns the source section definition with all nested sections.
  """
  def section do
    %Spark.Dsl.Section{
      name: :source,
      describe: "Data fetching, action mapping, and preloading configuration.",
      schema: @source_schema,
      sections: [
        actions_section(),
        preload_section(),
        archive_section()
      ]
    }
  end
end
