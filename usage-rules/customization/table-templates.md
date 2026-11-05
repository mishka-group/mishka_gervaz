# Custom table templates

A **template** answers *where things go*: rows and columns, cards, a gallery, grouped sections.
It never decides how a button looks — that is the [UI adapter](ui-adapters.md).

Built in: `MishkaGervaz.Table.Templates.Table` (default) ·
`MishkaGervaz.Table.Templates.MediaGallery`.

```elixir
presentation do
  template MyAppWeb.Templates.PostCard
  switchable_templates [MishkaGervaz.Table.Templates.Table, MyAppWeb.Templates.PostCard]
  template_options columns: 3
end
```

## Skeleton

`use MishkaGervaz.Table.Behaviours.Template` gives you working defaults for eight of the callbacks
— all rendering `MishkaGervaz.Table.Templates.Shared` furniture — and imports `get_cell_value/2`.

```elixir
defmodule MyAppWeb.Templates.PostCard do
  use MishkaGervaz.Table.Behaviours.Template
  use MishkaGervaz.Messages                      # dgettext/2 in the mishka_gervaz domain

  import MishkaGervaz.Helpers,
    only: [dynamic_component: 1, get_visible_columns: 2, accessible?: 2]

  alias MishkaGervaz.Table.Templates.Shared

  @impl true
  def name, do: :post_card                       # what `state.template.name()` returns

  @impl true
  def label, do: "Cards"                         # switcher label

  @impl true
  def icon, do: "hero-squares-2x2"               # switcher glyph

  @impl true
  def description, do: "Post cards with a cover image"

  @impl true
  def features, do: [:filter, :select, :bulk_actions, :paginate]

  @impl true
  def default_options, do: [columns: 3]

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@static.id}>
      …
    </div>
    """
  end

  @impl true
  def render_item(assigns) do
    ~H"<article>…</article>"
  end
end
```

## Callbacks

| Callback | Required | Default from `use` |
|---|---|---|
| `name/0` | ✔ | — |
| `label/0` | ✔ | — |
| `icon/0` | ✔ | — |
| `description/0` | ✔ | — |
| `features/0` | ✔ | — |
| `default_options/0` | ✔ | — |
| `render/1` | ✔ | — |
| `render_item/1` | ✔ | — |
| `render_header/1` | — | `Shared.render_header/1` (renders nothing) |
| `render_empty/1` | — | `Shared.render_empty_state/1`, reading the DSL's `empty_state` |
| `render_error/1` | — | `Shared.render_error_state/1`, reading the DSL's `error_state`, through the resource's UI adapter |
| `render_loading/1` | — | `Shared.render_loading/1` |
| `render_pagination/1` | — | `Shared.render_pagination/1` |
| `render_filters/1` | — | `Shared.render_filters/1` |
| `render_bulk_actions/1` | — | `Shared.render_bulk_actions/1` |
| `render_template_switcher/1` | — | `Shared.render_template_switcher/1` |

> Override a callback when the **markup** differs, not the wording. `empty_state` and
> `error_state` are DSL entries — a template that only wants a different message or icon says so
> [there](../table/states.md).

## Assigns the renderer passes

| Assign | Contents |
|---|---|
| `@static` | `MishkaGervaz.Table.Web.State.Static` — id, columns, filters, row_actions, bulk_actions, ui_adapter, features, theme, header/footer/notices, template_options, … **same reference always**, so LiveView skips re-render |
| `@state` | the dynamic state — page, filter_values, selected_ids, archive_status, loading, records_result, loaded_records, path_params, … |
| `@stream` | the LiveView stream for `static.stream_name` — the only place a load's rows reach the template; `records_result` holds the last load's `%{page:, empty?:}`, not its rows |
| `@empty?` | whether the table has nothing to show |
| `@failed?` | whether no read has succeeded and the last one failed; draw `render_error/1` in place of the rows, and keep the filters |
| `@myself` | the LiveComponent target for `phx-target` |

Read config out of `@static`, never re-derive it from the resource.

## `Shared` — do not re-implement the furniture

`MishkaGervaz.Table.Templates.Shared` is public API. The pieces a custom template reaches for
most:

| Helper | Use |
|---|---|
| `render_cell/1` | one cell, honouring `format`, `render` and the column type |
| `render_row_actions/1` | the action strip, with `visible` already applied |
| `non_accordion_actions/1` | actions minus `:accordion` — keeps the expander out of the strip |
| `expandable_rows?/2`, `expandable?/3` | whether to draw a caret column, and a caret on this row, from the `:accordion` action's `visible` and `restricted` |
| `has_user_visible_actions?/2` | whether to draw an action area at all |
| `action_visible?/3` | the `:active` / `:archived` / `fn record, state` rule |
| `render_filters/1`, `render_pagination/1`, `render_bulk_actions/1` | the standard bars |
| `render_empty_state/1`, `render_error_state/1`, `render_loading/1` | the standard states |
| `record_checked?/2` | selection state, including `select_all?` + `excluded_ids` |
| `custom_row_class/2` | the DSL's `row do class do apply … end end` |
| `has_visible_bulk_actions?/2` | whether the bulk bar has anything to show |
| `prepare_filter_groups/3`, `accessible_group?/2`, `grid_cols/1` | filter panel layout |
| `build_active_filter_chips/2` | the "currently filtering by" chips |
| `pagination_type/1` | `:numbered` / `:load_more` / `:infinite` from the config |

And from `MishkaGervaz.Helpers`: `get_visible_columns/2` (applies each column's `visible`),
`accessible?/2` (applies `restricted`), `dynamic_component/1` (dispatch to the UI adapter).

## Reading cells

```elixir
value = MishkaGervaz.Table.Behaviours.Template.get_cell_value(record, column)
```

It resolves every `source` shape — atom, `{relation, field}`, merged lists — plus `default` and
`separator`. To render the cell the way the plain table does (honouring `format`, `render` and the
column type), call `Shared.render_cell/1` instead of doing it by hand.

## Two templates, one resource

Declare every column and let `visible` decide which template shows it:

```elixir
column :stats, do: visible fn state -> state.template.name() == :table end
column :cover, do: visible fn state -> state.template.name() == :post_card end
```

The same trick works for row actions (`fn record, state -> state.template == @table_template end`).
Add `:template` to `url_sync.params` to make the reader's choice bookmarkable.

## Pairing a UI adapter

A template may ask for its own adapter when the resource has not named one — that is how
`Templates.MediaGallery` reaches `UIAdapters.MediaGallery`, so a card carries the same buttons on
every surface that borrows it. Do this by swapping `assigns.static.ui_adapter` inside `render/1`,
and only when the resource left it at the default.

## Grouped templates need `keep_loaded_records`

A LiveView stream is one flat appending container — it cannot express a section heading. A
template that **groups** rows must render from `state.loaded_records` instead of `@streams`, and
therefore needs:

```elixir
presentation do
  keep_loaded_records true
end
```

Without it, `:load_more` / `:infinite` would show only the newest page. With it, every loaded row
stays in the LiveView's memory — so use it only for grouped templates.

## TODO
- [ ] `use MishkaGervaz.Table.Behaviours.Template` rather than `@behaviour` + 16 stubs
- [ ] The six metadata callbacks + `render/1` + `render_item/1` implemented
- [ ] `name/0` is what your `visible` predicates compare against
- [ ] `features/0` lists only what the template genuinely draws
- [ ] Config read from `@static`, dynamic values from `@state`
- [ ] `Shared.*` reused instead of re-implementing filters / pagination / actions
- [ ] `id={@static.id}` on the root element
- [ ] Registered in `switchable_templates` if the reader may switch to it
- [ ] `keep_loaded_records true` if the template groups rows

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Behaviour:** `MishkaGervaz.Table.Behaviours.Template` ·
**Helpers:** `MishkaGervaz.Table.Templates.Shared`, `MishkaGervaz.Helpers` ·
**Read as examples:** `Table.Templates.Table`, `Table.Templates.MediaGallery`
