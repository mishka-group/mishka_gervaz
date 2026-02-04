defmodule MishkaGervaz.Table.Dsl.UrlSync do
  @moduledoc """
  DSL section for URL state synchronization at the resource level.

  This allows overriding domain-level url_sync defaults for specific resources.

  ## Example

      mishka_gervaz do
        table do
          url_sync do
            enabled true
            params [:filters, :sort, :page, :template]
            prefix "users"  # URL params will be ?users_filter_status=active
          end
        end
      end

  ## Options

  - `enabled` - Enable/disable URL sync for this resource
  - `params` - Which state to sync (filters, sort, page, search, template)
  - `prefix` - Prefix for URL params to avoid conflicts between tables
  """

  @schema [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable URL state synchronization. Overrides domain default."
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
      doc: "Which state to sync to URL params. Overrides domain default."
    ],
    prefix: [
      type: :string,
      doc: "Prefix for URL params. Overrides domain default."
    ],
    max_filter_length: [
      type: :pos_integer,
      default: 500,
      doc: "Maximum length for filter values. Values exceeding this are ignored. Default: 500."
    ],
    preserve_params: [
      type: {:or, [{:in, [:all]}, {:list, :atom}]},
      doc:
        "Params to preserve in URL across re-encoding. :all keeps all unknown params, or provide a list of specific param names. Preserved params are NOT stored in table state. max_filter_length applies to values."
    ]
  ]

  @doc """
  Returns the url_sync section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :url_sync,
      describe: "URL state synchronization. Overrides domain defaults if set.",
      schema: @schema
    }
  end
end
