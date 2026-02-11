defmodule MishkaGervaz.Table.Dsl.Defaults do
  @moduledoc """
  DSL section for domain-level table configuration.

  These table defaults are inherited by all resources in the domain
  that use `MishkaGervaz.Resource`.

  Used by `MishkaGervaz.Domain` extension.
  """

  alias MishkaGervaz.Table.Entities.Pagination

  @actions_schema [
    read: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_read, :tenant_read},
      doc: "Default read action or {master_action, tenant_action}."
    ],
    get: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_get, :read},
      doc: "Default get action."
    ],
    destroy: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: {:master_destroy, :destroy},
      doc: "Default destroy action."
    ]
  ]

  @realtime_schema [
    enabled: [
      type: :boolean,
      default: true,
      doc:
        "Default realtime enabled. When realtime section is defined, enabled is true by default."
    ],
    pubsub: [
      type: :atom,
      doc: "Default PubSub module."
    ]
  ]

  @theme_schema [
    header_class: [
      type: :string,
      doc: "Default header CSS classes."
    ],
    row_class: [
      type: :string,
      doc: "Default row CSS classes."
    ],
    border_class: [
      type: :string,
      doc: "Default border CSS classes."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Default extra theme options."
    ]
  ]

  @url_sync_schema [
    enabled: [
      type: :boolean,
      default: true,
      doc:
        "Enable URL state synchronization. When url_sync section is defined, enabled is true by default."
    ],
    mode: [
      type: {:in, [:read_only, :bidirectional]},
      default: :read_only,
      doc: """
      URL sync mode:
      - `:read_only` - Only read from URL on initial load (default)
      - `:bidirectional` - Sync URL when filters/sort/page change
      """
    ],
    params: [
      type: {:list, {:in, [:filters, :sort, :page, :search, :template]}},
      default: [:filters, :sort, :page],
      doc: "Which state to sync to URL params."
    ],
    prefix: [
      type: :string,
      doc: "Prefix for URL params to avoid conflicts."
    ]
  ]

  @refresh_schema [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable auto-refresh. When refresh section is defined, enabled is true by default."
    ],
    interval: [
      type: :pos_integer,
      default: 30_000,
      doc: "Refresh interval in milliseconds. Default: 30 seconds."
    ],
    pause_on_interaction: [
      type: :boolean,
      default: true,
      doc: "Pause auto-refresh when user is interacting (filtering, selecting, etc.)."
    ],
    show_indicator: [
      type: :boolean,
      default: true,
      doc: "Show a visual indicator when auto-refresh is active."
    ],
    pause_on_blur: [
      type: :boolean,
      default: true,
      doc: "Pause auto-refresh when browser tab/window loses focus."
    ]
  ]

  @schema [
    ui_adapter: [
      type: :atom,
      default: MishkaGervaz.UIAdapters.Tailwind,
      doc: "Default UI adapter module."
    ],
    ui_adapter_opts: [
      type: :keyword_list,
      default: [],
      doc: "Default UI adapter options."
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
      name: :table,
      describe: "Table configuration inherited by all resources in this domain.",
      schema: @schema,
      sections: [
        actions_section(),
        realtime_section(),
        theme_section(),
        url_sync_section(),
        refresh_section()
      ],
      entities: [
        pagination_entity()
      ]
    }
  end

  defp actions_section do
    %Spark.Dsl.Section{
      name: :actions,
      describe: "Default action mapping.",
      schema: @actions_schema
    }
  end

  defp pagination_entity do
    %Spark.Dsl.Entity{
      name: :pagination,
      describe: "Default pagination configuration.",
      target: Pagination,
      schema: Pagination.opt_schema(),
      entities: [ui: [pagination_ui_entity()]],
      transform: {Pagination, :transform, []}
    }
  end

  defp pagination_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for pagination.",
      target: Pagination.Ui,
      schema: Pagination.Ui.opt_schema(),
      transform: {Pagination.Ui, :transform, []}
    }
  end

  defp realtime_section do
    %Spark.Dsl.Section{
      name: :realtime,
      describe: "Default realtime configuration.",
      schema: @realtime_schema
    }
  end

  defp theme_section do
    %Spark.Dsl.Section{
      name: :theme,
      describe: "Default theme configuration.",
      schema: @theme_schema
    }
  end

  defp url_sync_section do
    %Spark.Dsl.Section{
      name: :url_sync,
      describe: "URL state synchronization for bookmarkable views.",
      schema: @url_sync_schema
    }
  end

  defp refresh_section do
    %Spark.Dsl.Section{
      name: :refresh,
      describe: "Auto-refresh configuration for automatic table data reloading.",
      schema: @refresh_schema
    }
  end
end
