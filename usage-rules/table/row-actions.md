# Table → `row_actions`

Per-row buttons and dropdowns, and which of them stay inline.

```elixir
row_actions do
  actions_layout do
    position :end              # :start | :end
    sticky true                # stick on horizontal scroll
    inline [:edit, :archive]
    dropdown [:more]
    auto_collapse_after 3
  end

  action :edit do
    type :edit
    visible :active
    js fn _record -> MyAppWeb.CoreComponents.show_modal("post-form-modal") end
    ui do label fn -> dgettext("mishka_gervaz", "Edit") end; icon "hero-pencil" end
  end

  action :publish do
    type :update
    action {:master_publish, :publish}
  end

  action :expand, type: :accordion

  dropdown :more do
    ui do label fn -> dgettext("mishka_gervaz", "Actions") end; icon "hero-ellipsis-vertical" end

    action :versions do type :event; event "show_versions" end
    separator label: "Permanent"
    action :nuke do
      type :permanent_destroy
      visible :archived
      confirm "Permanently delete? This cannot be undone."
    end
  end
end
```

## `type` is required

`:link` · `:event` · `:edit` · `:destroy` · `:update` · `:unarchive` · `:permanent_destroy` ·
`:row_click` · `:accordion` · `:modal` · or an `ActionType` module
([../customization/types.md](../customization/types.md)).

| Option | Type | Note |
|---|---|---|
| `path` | string \| `fn record -> string` | `:link`; supports `{field}` interpolation |
| `event` | atom \| string | `:event`; reaches the parent as `{:row_action, event, payload}` |
| `action` | atom \| `{master, tenant}` | the Ash action for `:update` |
| `payload` | `fn record -> map` | |
| `confirm` | string \| `fn record -> string` | supports `{field}` |
| `restricted` | bool | master-only |
| `visible` | `:active` (default) \| `:archived` \| bool \| **`fn record, state ->`** | arity **2** |
| `js` | `fn record -> %JS{}` | chained onto the click |
| `render` | `fn record ->` / `fn record, action ->` / `fn record, action, target ->` | |

`ui`: `label` (defaults to the humanized action name) · `icon` · `class` · `extra`.

## `visible` is arity 2 here

Unlike columns, filters and bulk actions, a row action's predicate receives **`(record, state)`**:

```elixir
visible fn _record, state ->
  state.archive_status == :active and state.template == @table_template
end
```

This is how one resource drives two templates: declare every action, and let `visible` decide
which appear in the card view and which in the plain table.

## `:accordion`

Declares that a row expands — it is **not** drawn as a button. The plain table renders its own
caret; a card template renders its own footer. Pair it with the `on_expand` hook and push the
panel back with `send_update(..., expanded_html: html)` — see
[../mounting.md](../mounting.md).

## `dropdown`

Contains `action` and `separator` entities. `separator label: "Permanent"` draws a labelled
divider. `ui` on the dropdown itself styles the trigger.

## `actions_layout`

Names which actions render inline and which collapse into a dropdown. Every name listed must
exist. `auto_collapse_after N` folds everything past the Nth.

## Rules the compiler enforces

- `type :link` requires `path`.
- `type :event` requires `event`.
- A `dropdown` requires a `ui` block **with a `label`** — including for actions nested inside it.

## The action types — compared

| `type` | What it does | Needs | Message to the parent |
|---|---|---|---|
| `:link` | navigates | `path` | — |
| `:event` | fires a custom event | `event` | `{:row_action, event, payload}` |
| `:edit` | opens the resource's form | the form section | none — `send_update`s the form component directly |
| `:destroy` | soft-deletes | `source.actions.destroy` | — |
| `:update` | runs an Ash action | `action` | — |
| `:unarchive` | restores | `source.archive.restore_action` | — |
| `:permanent_destroy` | hard-deletes | `source.archive.destroy_action` | — |
| `:row_click` | makes the whole row clickable | `event` / `path` | as for its shape |
| `:accordion` | declares the row expands | the `on_expand` hook | `{:expand_row, id}` |
| `:modal` | a modal-opening button | your own `js` / `event` | as for its shape |
| a module | anything | the `ActionType` behaviour | yours |

`:edit` needs **no** parent message: the component calls
`send_update(MishkaGervaz.Form.Web.Live, id: FormInfo.component_id(resource), record_id: id)`
itself. Add a `js` to open the modal and nothing else.

## TODO
- [ ] `type` on every action
- [ ] `:link` actions have `path`; `:event` actions have `event`
- [ ] Every `dropdown` has `ui do label … end`
- [ ] `visible fn` has arity **2** (`record, state`)
- [ ] `:update` actions name their Ash `action`
- [ ] `:unarchive` / `:permanent_destroy` gated with `visible :archived`
- [ ] Every name in `actions_layout` / `inline` / `dropdown` exists
- [ ] Destructive actions carry `confirm`
- [ ] The table declares `source.actions.get` — most of these types need it

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.row_actions`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions) · [`mishka_gervaz.table.row_actions.action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-action) · [`mishka_gervaz.table.row_actions.action.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-action-ui) · [`mishka_gervaz.table.row_actions.actions_layout`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-actions_layout) · [`mishka_gervaz.table.row_actions.dropdown`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-dropdown) · [`mishka_gervaz.table.row_actions.dropdown.action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-dropdown-action) · [`mishka_gervaz.table.row_actions.dropdown.separator`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-dropdown-separator)

**Schema:** `MishkaGervaz.Table.Entities.RowAction`, `.RowAction.Ui`, `.RowActionDropdown`,
`.DropdownSeparator` · **Verifier:** `Table.Verifiers.ValidateRowActions` ·
**Types:** `MishkaGervaz.Table.Types.Action`
