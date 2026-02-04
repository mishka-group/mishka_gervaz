defmodule MishkaGervaz do
  @moduledoc """
  MishkaGervaz is a Spark-based DSL library that provides declarative admin table
  configuration for Ash Framework resources.

  ## Usage

  Add the extension to your Ash resource:

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

  ## Design Principles

  1. **Separation of Concerns**: `source` = data/behavior, `ui` = presentation, `render` = custom output
  2. **Smart Type Inference**: Single `source` key detects intent from value shape
  3. **Everything Optional**: Sensible defaults everywhere, minimal required config
  4. **Template Agnostic**: `ui.extra` map for template-specific options
  5. **Multi-tenant First**: Built-in master/tenant user handling

  ## Sections

  The DSL provides the following sections within the `table` block:

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
  - `presentation` - Template selection and theming. See `MishkaGervaz.Table.Dsl.Presentation`
  - `refresh` - Auto-refresh configuration. See `MishkaGervaz.Table.Dsl.Refresh`
  - `url_sync` - URL state synchronization. See `MishkaGervaz.Table.Dsl.UrlSync`
  - `hooks` - Lifecycle callbacks. See `MishkaGervaz.Table.Dsl.Hooks`

  See `MishkaGervaz.Resource.Info.Table` for introspection functions.
  """
end
