defmodule MishkaGervaz.Resource do
  @moduledoc """
  Ash extension for MishkaGervaz admin UI DSL.

  Add this extension to your Ash resources to enable declarative admin table configuration:

      defmodule MyApp.CMS.Component do
        use Ash.Resource,
          domain: MyApp.CMS,
          extensions: [MishkaGervaz.Resource]

        mishka_gervaz do
          table do
            identity do
              route "/admin/components"
            end

            columns do
              column :name, sortable: true
              column :status
            end

            row_actions do
              action :edit, type: :link
              action :delete, type: :destroy
            end
          end
        end

        # ... rest of Ash resource
      end

  ## Sections

  The DSL provides the following sections within `mishka_gervaz -> table`:

  - `identity` - Naming and routing. See `MishkaGervaz.Table.Dsl.Identity`
  - `source` - Data fetching, action mapping, preloading. See `MishkaGervaz.Table.Dsl.Source`
  - `realtime` - PubSub configuration. See `MishkaGervaz.Table.Entities.Realtime`
  - `columns` - Define table columns. See `MishkaGervaz.Table.Dsl.Columns`
  - `filters` - Filter input configuration. See `MishkaGervaz.Table.Dsl.Filters`
  - `row_actions` - Per-row action buttons. See `MishkaGervaz.Table.Dsl.RowActions`
  - `row` - Row styling and behavior. See `MishkaGervaz.Table.Dsl.Row`
  - `bulk_actions` - Actions on multiple selected rows. See `MishkaGervaz.Table.Dsl.BulkActions`
  - `pagination` - Pagination configuration. See `MishkaGervaz.Table.Entities.Pagination`
  - `empty_state` - Empty state configuration. See `MishkaGervaz.Table.Entities.EmptyState`
  - `error_state` - Error state configuration. See `MishkaGervaz.Table.Entities.ErrorState`
  - `presentation` - UI adapter and theming. See `MishkaGervaz.Table.Dsl.Presentation`
  - `refresh` - Auto-refresh configuration. See `MishkaGervaz.Table.Dsl.Refresh`
  - `url_sync` - URL state synchronization. See `MishkaGervaz.Table.Dsl.UrlSync`
  - `hooks` - Lifecycle callbacks. See `MishkaGervaz.Table.Dsl.Hooks`

  ## Introspection

  Use `MishkaGervaz.Resource.Info.Table` to introspect the configuration at runtime:

      # Get the full compiled config
      config = MishkaGervaz.Resource.Info.Table.config(MyResource)

      # Get columns
      columns = MishkaGervaz.Resource.Info.Table.columns(MyResource)

      # Get filters
      filters = MishkaGervaz.Resource.Info.Table.filters(MyResource)
  """

  @mishka_gervaz %Spark.Dsl.Section{
    name: :mishka_gervaz,
    describe: "MishkaGervaz admin UI DSL configuration.",
    sections: [
      MishkaGervaz.Table.Dsl.section()
    ]
  }

  @transformers [
    MishkaGervaz.Table.Transformers.MergeDefaults,
    MishkaGervaz.Table.Transformers.ResolveColumns,
    MishkaGervaz.Table.Transformers.BuildRuntimeConfig
  ]

  @verifiers [
    MishkaGervaz.Table.Verifiers.ValidateIdentity,
    MishkaGervaz.Table.Verifiers.ValidateSource,
    MishkaGervaz.Table.Verifiers.ValidateColumns,
    MishkaGervaz.Table.Verifiers.ValidateFilters,
    MishkaGervaz.Table.Verifiers.ValidateRowActions,
    MishkaGervaz.Table.Verifiers.ValidateBulkActions
  ]

  use Spark.Dsl.Extension,
    sections: [@mishka_gervaz],
    transformers: @transformers,
    verifiers: @verifiers
end
