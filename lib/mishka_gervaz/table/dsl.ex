defmodule MishkaGervaz.Table.Dsl do
  @moduledoc """
  Table DSL definitions for MishkaGervaz.

  This module assembles all the table-related DSL sections into a single `table` section.
  Each section is defined in its own module under `MishkaGervaz.Table.Dsl.*`.

  ## Sections

  - `MishkaGervaz.Table.Dsl.Identity` - Naming and routing
  - `MishkaGervaz.Table.Dsl.Source` - Data fetching, action mapping, preloading
  - `MishkaGervaz.Table.Dsl.Columns` - Define table columns
  - `MishkaGervaz.Table.Dsl.Filters` - Filter input configuration
  - `MishkaGervaz.Table.Dsl.FilterGroups` - Group filters into collapsible UI panels
  - `MishkaGervaz.Table.Dsl.RowActions` - Per-row action buttons
  - `MishkaGervaz.Table.Dsl.Row` - Row styling and behavior
  - `MishkaGervaz.Table.Dsl.BulkActions` - Actions on multiple selected rows
  - `MishkaGervaz.Table.Dsl.Layout` - Header / footer / notices layout
  - `MishkaGervaz.Table.Dsl.Presentation` - UI adapter and theming
  - `MishkaGervaz.Table.Dsl.Hooks` - Lifecycle callbacks
  - `MishkaGervaz.Table.Dsl.Refresh` - Auto-refresh configuration
  - `MishkaGervaz.Table.Dsl.UrlSync` - URL state synchronization
  - `MishkaGervaz.Table.Dsl.State` - State management module overrides

  ## Top-level entities

  - `MishkaGervaz.Table.Dsl.Realtime` - PubSub configuration (inline or block)
  - `MishkaGervaz.Table.Dsl.Pagination` - Pagination configuration (inline or block)
  - `MishkaGervaz.Table.Dsl.States` - `empty_state` / `error_state` entities
  - `MishkaGervaz.Table.Dsl.DataLoader` - Data loader module overrides
  - `MishkaGervaz.Table.Dsl.Events` - Event handler module overrides

  Admin-sidebar grouping (`MishkaGervaz.Dsl.Navigation`) is declared at
  the **domain** level, not inside a resource's `table do` — see
  `MishkaGervaz.Domain`.

  ## Structure

  ```
  mishka_gervaz do
    table do
      identity do ... end
      source do ... end
      realtime enabled: true, pubsub: MyApp.PubSub
      columns do ... end
      filters do ... end
      filter_groups do ... end
      row_actions do ... end
      row do ... end
      bulk_actions do ... end
      layout do ... end
      pagination page_size: 20, type: :infinite
      empty_state message: "No records found"
      error_state message: "Error loading data"
      presentation do ... end
      hooks do ... end
      refresh do ... end
      url_sync do ... end
      state do ... end
      data_loader do ... end
      events do ... end
    end
  end
  ```

  See `MishkaGervaz.Resource`, `MishkaGervaz.Domain`,
  `MishkaGervaz.Table.Entities.Column`,
  `MishkaGervaz.Table.Entities.Filter`,
  `MishkaGervaz.Table.Entities.RowAction`,
  `MishkaGervaz.Table.Entities.BulkAction`,
  `MishkaGervaz.Table.Entities.Pagination`,
  `MishkaGervaz.Table.Entities.Realtime`,
  and `MishkaGervaz.Table.Web.Live`.
  """

  alias MishkaGervaz.Table.Dsl.{
    Identity,
    Source,
    Realtime,
    Columns,
    Filters,
    FilterGroups,
    RowActions,
    Row,
    BulkActions,
    Pagination,
    States,
    Presentation,
    Hooks,
    Refresh,
    UrlSync,
    Layout
  }

  alias MishkaGervaz.Table.Dsl.State, as: StateDsl
  alias MishkaGervaz.Table.Dsl.DataLoader, as: DataLoaderDsl
  alias MishkaGervaz.Table.Dsl.Events, as: EventsDsl

  @doc """
  Returns the `table` section definition.

  This section contains all table configuration subsections.
  """
  def section do
    %Spark.Dsl.Section{
      name: :table,
      describe: "Table configuration for admin interfaces.",
      sections: [
        Identity.section(),
        Source.section(),
        Columns.section(),
        Filters.section(),
        FilterGroups.section(),
        RowActions.section(),
        Row.section(),
        BulkActions.section(),
        Layout.section(),
        Presentation.section(),
        Hooks.section(),
        Refresh.section(),
        UrlSync.section(),
        StateDsl.section()
      ],
      entities: [
        Realtime.entity(),
        Pagination.entity(),
        States.empty_state_entity(),
        States.error_state_entity(),
        DataLoaderDsl.entity(),
        EventsDsl.entity()
      ]
    }
  end
end
