defmodule MishkaGervaz.Resource do
  @moduledoc """
  Ash extension for MishkaGervaz admin UI DSL.

  Add this extension to your Ash resources to enable declarative admin table
  and form configuration. The top-level `mishka_gervaz` block contains two
  sibling sections — `table` (admin list view) and `form` (create/edit form) —
  which may be used independently or together on a single resource.

  ### Table example

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

  ### Form example

      mishka_gervaz do
        form do
          identity do
            name :component_form
            route "/admin/components"
          end

          source do
            actor_key :current_user
            master_check fn user -> user.role == :admin end

            actions do
              create {:master_create, :create}
              update {:master_update, :update}
              read {:master_get, :read}
            end
          end

          fields do
            field :name, :text, required: true
            field :status, :select
          end
        end
      end

  ## Table sections

  The following sections live within `mishka_gervaz -> table`:

  - `identity` - Naming and routing. See `MishkaGervaz.Table.Dsl.Identity`
  - `source` - Data fetching, action mapping, preloading. See `MishkaGervaz.Table.Dsl.Source`
  - `realtime` - PubSub configuration. See `MishkaGervaz.Table.Entities.Realtime`
  - `columns` - Define table columns. See `MishkaGervaz.Table.Dsl.Columns`
  - `filters` - Filter input configuration. See `MishkaGervaz.Table.Dsl.Filters`
  - `filter_groups` - Group filters in the UI. See `MishkaGervaz.Table.Dsl.FilterGroups`
  - `row_actions` - Per-row action buttons. See `MishkaGervaz.Table.Dsl.RowActions`
  - `row` - Row styling and behavior. See `MishkaGervaz.Table.Dsl.Row`
  - `bulk_actions` - Actions on multiple selected rows. See `MishkaGervaz.Table.Dsl.BulkActions`
  - `layout` - Layout mode and template switcher. See `MishkaGervaz.Table.Dsl.Layout`
  - `pagination` - Pagination configuration. See `MishkaGervaz.Table.Entities.Pagination`
  - `empty_state` - Empty state configuration. See `MishkaGervaz.Table.Entities.EmptyState`
  - `error_state` - Error state configuration. See `MishkaGervaz.Table.Entities.ErrorState`
  - `presentation` - UI adapter and theming. See `MishkaGervaz.Table.Dsl.Presentation`
  - `refresh` - Auto-refresh configuration. See `MishkaGervaz.Table.Dsl.Refresh`
  - `url_sync` - URL state synchronization. See `MishkaGervaz.Table.Dsl.UrlSync`
  - `hooks` - Lifecycle callbacks. See `MishkaGervaz.Table.Dsl.Hooks`
  - `state` - State-module overrides (`column`, `filter`, `action`, `presentation`, `url_sync`, `access`, `module`). See `MishkaGervaz.Table.Dsl.State`
  - `data_loader` - Data-loader sub-builder overrides (`query`, `filter_parser`, `pagination`, `tenant`, `relation`, `hooks`, `module`). See `MishkaGervaz.Table.Entities.DataLoader`
  - `events` - Event-handler sub-builder overrides (`sanitization`, `record`, `selection`, `bulk_action`, `relation_filter`, `hooks`, `module`). See `MishkaGervaz.Table.Entities.Events`

  ## Form sections

  The following sections live within `mishka_gervaz -> form`:

  - `identity` - Naming and routing. See `MishkaGervaz.Form.Dsl.Identity`
  - `source` - Data fetching, action mapping, preloading. See `MishkaGervaz.Form.Dsl.Source`
  - `fields` - Define form fields. See `MishkaGervaz.Form.Dsl.Fields`
  - `groups` - Define field groups. See `MishkaGervaz.Form.Dsl.Groups`
  - `layout` - Layout mode (`:standard` / `:wizard` / `:tabs`) and step definitions. See `MishkaGervaz.Form.Dsl.Layout`
  - `uploads` - File upload configuration. See `MishkaGervaz.Form.Dsl.Uploads`
  - `presentation` - UI adapter and theming. See `MishkaGervaz.Form.Dsl.Presentation`
  - `hooks` - Lifecycle callbacks. See `MishkaGervaz.Form.Dsl.Hooks`
  - `state` - State-module overrides (`field`, `group`, `step`, `presentation`, `access`, `module`). See `MishkaGervaz.Form.Dsl.State`
  - `submit` - Submit / update / cancel button labels. See `MishkaGervaz.Form.Entities.Submit`
  - `data_loader` - Data-loader sub-builder overrides (`record`, `tenant`, `relation`, `hooks`, `module`). See `MishkaGervaz.Form.Entities.DataLoader`
  - `events` - Event-handler sub-builder overrides (`sanitization`, `validation`, `submit`, `step`, `upload`, `relation`, `hooks`, `module`). See `MishkaGervaz.Form.Entities.Events`

  ## Introspection

  Use `MishkaGervaz.Resource.Info.Table` and `MishkaGervaz.Resource.Info.Form`
  to introspect the configuration at runtime:

      # Table — full compiled config / columns / filters
      config  = MishkaGervaz.Resource.Info.Table.config(MyResource)
      columns = MishkaGervaz.Resource.Info.Table.columns(MyResource)
      filters = MishkaGervaz.Resource.Info.Table.filters(MyResource)

      # Form — full compiled config / fields / groups / events / state / data_loader
      config      = MishkaGervaz.Resource.Info.Form.config(MyResource)
      fields      = MishkaGervaz.Resource.Info.Form.fields(MyResource)
      groups      = MishkaGervaz.Resource.Info.Form.groups(MyResource)
      events      = MishkaGervaz.Resource.Info.Form.events(MyResource)
      state       = MishkaGervaz.Resource.Info.Form.state(MyResource)
      data_loader = MishkaGervaz.Resource.Info.Form.data_loader(MyResource)
  """

  @mishka_gervaz %Spark.Dsl.Section{
    name: :mishka_gervaz,
    describe: "MishkaGervaz admin UI DSL configuration.",
    sections: [
      MishkaGervaz.Table.Dsl.section(),
      MishkaGervaz.Form.Dsl.section()
    ]
  }

  @transformers [
    MishkaGervaz.Table.Transformers.MergeDefaults,
    MishkaGervaz.Table.Transformers.ResolveColumns,
    MishkaGervaz.Table.Transformers.BuildRuntimeConfig,
    MishkaGervaz.Form.Transformers.MergeDefaults,
    MishkaGervaz.Form.Transformers.ResolveFields,
    MishkaGervaz.Form.Transformers.BuildRuntimeConfig
  ]

  @verifiers [
    MishkaGervaz.Table.Verifiers.ValidateIdentity,
    MishkaGervaz.Table.Verifiers.ValidateSource,
    MishkaGervaz.Table.Verifiers.ValidateColumns,
    MishkaGervaz.Table.Verifiers.ValidateFilters,
    MishkaGervaz.Table.Verifiers.ValidateRowActions,
    MishkaGervaz.Table.Verifiers.ValidateBulkActions,
    MishkaGervaz.Table.Verifiers.ValidatePagination,
    MishkaGervaz.Table.Verifiers.ValidateLayout,
    MishkaGervaz.Form.Verifiers.ValidateIdentity,
    MishkaGervaz.Form.Verifiers.ValidateSource,
    MishkaGervaz.Form.Verifiers.ValidateFields,
    MishkaGervaz.Form.Verifiers.ValidateGroups,
    MishkaGervaz.Form.Verifiers.ValidateSteps,
    MishkaGervaz.Form.Verifiers.ValidateUploads,
    MishkaGervaz.Form.Verifiers.ValidatePreloads,
    MishkaGervaz.Form.Verifiers.ValidateChrome
  ]

  use Spark.Dsl.Extension,
    sections: [@mishka_gervaz],
    transformers: @transformers,
    verifiers: @verifiers
end
