# Overriding builders, handlers and loaders

The deepest layer: replace how state is built, how events are handled, or how data is loaded.
Every sub-module is `use`-able and every callback is `defoverridable`, so an override is one
function plus `super`.

Reach for this only after DSL options, `render`, a custom type, an adapter and a template have all
been ruled out ([../customization.md](../customization.md)).

## The pattern

```elixir
defmodule MyApp.Form.SubmitHandler do
  use MishkaGervaz.Form.Web.Events.SubmitHandler

  def transform_params(state, params) do
    state
    |> super(params)
    |> Map.put("ingested_at", DateTime.utc_now())
  end
end
```

```elixir
mishka_gervaz do
  form do
    events do
      submit MyApp.Form.SubmitHandler
    end
  end
end
```

The DSL config is read **at runtime** by the orchestrator — no macro tree is recompiled, and
`super` always reaches the default.

## Three granularities

```elixir
# 1 — one sub-builder
events do submit MyApp.Form.SubmitHandler end

# 2 — the whole subsystem, block form
events do module MyApp.Form.CustomEvents end

# 3 — the whole subsystem, positional form
events MyApp.Form.CustomEvents
```

When `module` is set, **every other key in that block is ignored**. The module must `use` the
corresponding parent (`MishkaGervaz.Form.Web.Events`, `…Table.Web.State`, …).

The `use` macro also accepts the same set as compile-time options, which is the way to build a
reusable bundle:

```elixir
defmodule MyApp.Table.State do
  use MishkaGervaz.Table.Web.State,
    column: MyApp.Table.ColumnBuilder,
    filter: MyApp.Table.FilterBuilder
end
```

## Table — what can be replaced

### `state do … end`

| Key | Module to `use` | Builds |
|---|---|---|
| `column` | `Table.Web.State.ColumnBuilder` | columns from the DSL + resource |
| `filter` | `Table.Web.State.FilterBuilder` | filters from the DSL + resource |
| `action` | `Table.Web.State.ActionBuilder` | row and bulk actions |
| `presentation` | `Table.Web.State.Presentation` | UI adapter, template, options |
| `url_sync` | `Table.Web.State.UrlSync` | URL state synchronization |
| `access` | `Table.Web.State.Access` | record- and action-level access |
| `module` | `Table.Web.State` | all of the above |

### `data_loader do … end`

| Key | Module to `use` | Does |
|---|---|---|
| `query` | `Table.Web.DataLoader.QueryBuilder` | builds the query with filters and sorting |
| `filter_parser` | `Table.Web.DataLoader.FilterParser` | parses raw filter params |
| `pagination` | `Table.Web.DataLoader.PaginationHandler` | page loading and page maths |
| `tenant` | `Table.Web.DataLoader.TenantResolver` | resolves tenant + read action |
| `relation` | `Table.Web.DataLoader.RelationLoader` | relation filter options (search, load-more, resolve-selected) |
| `hooks` | `Table.Web.DataLoader.HookRunner` | hooks during loading |
| `module` | `Table.Web.DataLoader` | all of the above |

### `events do … end`

| Key | Module to `use` | Handles |
|---|---|---|
| `sanitization` | `Table.Web.Events.SanitizationHandler` | input sanitization (XSS) |
| `record` | `Table.Web.Events.RecordHandler` | record CRUD events |
| `selection` | `Table.Web.Events.SelectionHandler` | row selection state |
| `bulk_action` | `Table.Web.Events.BulkActionHandler` | bulk execution |
| `relation_filter` | `Table.Web.Events.RelationFilterHandler` | relation-filter search / load-more / focus / toggle |
| `hooks` | `Table.Web.Events.HookRunner` | hook dispatch |
| `module` | `Table.Web.Events` | all of the above |

## Form — what can be replaced

### `state do … end`

| Key | Module to `use` | Builds |
|---|---|---|
| `field` | `Form.Web.State.FieldBuilder` | resolved field configs |
| `group` | `Form.Web.State.GroupBuilder` | group layout |
| `step` | `Form.Web.State.StepBuilder` | wizard / tabs step plan |
| `presentation` | `Form.Web.State.Presentation` | adapter, template, theme, features, debounce |
| `access` | `Form.Web.State.Access` | master gate, action mapping, preload selection |
| `module` | `Form.Web.State` | all of the above |

### `data_loader do … end`

| Key | Module to `use` | Does |
|---|---|---|
| `record` | `Form.Web.DataLoader.RecordLoader` | loads the record, builds the `AshPhoenix.Form` |
| `tenant` | `Form.Web.DataLoader.TenantResolver` | resolves tenant + actions |
| `relation` | `Form.Web.DataLoader.RelationLoader` | relation / select options |
| `hooks` | `Form.Web.DataLoader.HookRunner` | hooks during loading |
| `module` | `Form.Web.DataLoader` | all of the above |

### `events do … end`

| Key | Module to `use` | Handles |
|---|---|---|
| `sanitization` | `Form.Web.Events.SanitizationHandler` | input sanitization (XSS) |
| `validation` | `Form.Web.Events.ValidationHandler` | the `phx-change` pass |
| `submit` | `Form.Web.Events.SubmitHandler` | `phx-submit`, create and update |
| `step` | `Form.Web.Events.StepHandler` | wizard navigation (next / prev / goto) |
| `upload` | `Form.Web.Events.UploadHandler` | upload events |
| `relation` | `Form.Web.Events.RelationHandler` | relation search / select / clear |
| `hooks` | `Form.Web.Events.HookRunner` | hook dispatch |
| `module` | `Form.Web.Events` | all of the above |

Defaults are the `.Default` submodule of each — e.g.
`MishkaGervaz.Form.Web.Events.SubmitHandler.Default`.

## The state struct is fixed

There is no `:custom_field`. To carry your own data:

- read-only config → put it on `state.static.config` at build time;
- per-interaction values → stage them on `state.field_values` (form) or use the existing dynamic
  fields (table).

Mutate with `State.update(state, key: value)`, never by rebuilding the struct.

## Helpers exist for override authors

`MishkaGervaz.Table.Web.State.Helpers`, `Form.Web.State.Helpers`,
`Table.Web.DataLoader.Helpers`, `Form.Web.DataLoader.Helpers` and
`Table.Web.Events.BulkActionHooks` are public precisely so an override can reuse the parts it is
not changing.

## Hook or override? — compared

| | Hook | Sub-builder override |
|---|---|---|
| Lives in | the resource's DSL | a module |
| Scope | one resource | every resource that wires it |
| Can it *replace* built-in behaviour? | only via `override_row_action` / `override_bulk_action` | yes, entirely |
| Cost | a function in the DSL | a module to maintain across upgrades |

Prefer a hook for anything resource-specific ([../table/hooks.md](../table/hooks.md) ·
[../form/hooks.md](../form/hooks.md)). Reach for an override when the *mechanism* is wrong for
your app, not the policy.

## TODO
- [ ] Everything above this layer ruled out first
- [ ] `use` the specific sub-module, not the whole subsystem, unless all of it changes
- [ ] `super` called rather than the default re-implemented
- [ ] The module is wired through the DSL, not hard-coded at the call site
- [ ] `module` used only when every key in the block would otherwise be overridden
- [ ] Custom data on `state.static.config` / `state.field_values`, not new struct fields
- [ ] `State.update/2` used for every mutation
- [ ] Sanitization overrides still sanitize

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Modules:** `MishkaGervaz.{Table,Form}.Web.{State,Events,DataLoader}` and their submodules ·
**DSL:** `{Table,Form}.Dsl.State`, `{Table,Form}.Entities.{DataLoader,Events}`
