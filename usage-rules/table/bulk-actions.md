# Table → `bulk_actions`

What can be done to a selection, and who executes it.

> **Bulk actions are what create the checkboxes.** The built-in templates draw them when
> `presentation.features` includes `:select` (the `:all` default does) **and** at least one bulk
> action is visible in the current archive scope. Declare `row do selectable true end` as well —
> it is what makes `source.actions.get` required — but the actions are the trigger.

```elixir
bulk_actions do
  enabled true

  action :archive, type: :destroy, confirm: "Archive selected posts?"
  action :unarchive, type: :unarchive, confirm: "Restore selected?", visible: :archived

  action :permanent_destroy,
    type: :permanent_destroy,
    confirm: "Permanently delete {count} records? This cannot be undone.",
    visible: :archived

  action :toggle_featured do
    handler {:master_toggle_featured, :toggle_featured}
    visible :active
    ui do label fn -> dgettext("mishka_gervaz", "Toggle Featured") end; icon "hero-star" end
  end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `type` | `:event` \| `:destroy` \| `:update` \| `:unarchive` \| `:permanent_destroy` | — | resolves the handler automatically |
| `action` | atom \| `{master, tenant}` | — | the Ash action for `:update` |
| `handler` | `:parent` \| `fn ids, state -> {:ok, state}` \| atom \| `{master, tenant}` | `:parent` | explicit handler wins over `type` |
| `confirm` | bool \| string | — | `{count}` becomes the number of rows the action runs on; with select all on a `:load_more` or `:infinite` table with `show_total false`, it stays as written while rows are left to load |
| `event` | atom | action name | for `:event` type |
| `payload` | `fn selected_ids -> map` | — | |
| `restricted` | bool | `false` | master-only |
| `visible` | `:active` \| `:archived` \| **`fn state ->`** | `:active` | arity **1** |

`ui`: `label` · `icon` · `class` · `extra`.

## Handler resolution

- `type` set and `handler` untouched → the handler becomes `{:type, type}` and routes through the
  master/tenant resolver.
- `handler` given one of the built-in type atoms (`:destroy`, `:unarchive`, …) → treated as a
  **type token**, not as an Ash action name, so `type: :destroy` and `handler: :destroy` behave
  identically.
- `handler :parent` (the default with no `type`) → sends `{:bulk_action, name, selected_ids}` to
  the parent LiveView; you execute it there.
- A function handler returns `{:ok, state}` or `{:error, term}`.

`ids` arrives as a list, `:all`, or `{:all_except, list}` — select-all does not enumerate the
whole table.

## Messaging the result

Bulk hooks (`on_bulk_action_success` / `on_bulk_action_error`, arity 3) decide whether the core
handler's default flash fires. See [hooks.md](hooks.md).

## Rules the compiler enforces

- A `bulk_actions do … end` block must define at least one action.
- Any bulk action makes `source.actions.get` required; a `:destroy` one makes `destroy` required.

## TODO
- [ ] `row do selectable true end` declared
- [ ] `visible fn` has arity **1** (unlike row actions)
- [ ] Custom handlers return `{:ok, state}` / `{:error, term}` and cope with `:all` / `{:all_except, ids}`
- [ ] Destructive actions carry `confirm`, using `{count}`
- [ ] An empty `bulk_actions` block is removed rather than left in

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.bulk_actions`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-bulk_actions) · [`mishka_gervaz.table.bulk_actions.action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-bulk_actions-action) · [`mishka_gervaz.table.bulk_actions.action.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-bulk_actions-action-ui)

**Schema:** `MishkaGervaz.Table.Entities.BulkAction`, `.BulkAction.Ui` ·
**Verifier:** `Table.Verifiers.ValidateBulkActions`
