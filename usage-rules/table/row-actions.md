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
`:row_click` · `:accordion` · `:modal` · `:drawer` · or an `ActionType` module
([../customization/types.md](../customization/types.md)).

| Option | Type | Note |
|---|---|---|
| `path` | string \| `fn record -> string` | `:link`; supports `{field}` interpolation; optional on `:show`/`:edit` links (built from the route) |
| `event` | atom \| string | `:event`; reaches the parent as `{:row_action, event, payload}` |
| `action` | atom \| `{master, tenant}` | the Ash action for `:update` |
| `payload` | `fn record -> map` | |
| `confirm` | string \| `fn record -> string` \| keyword list | a string asks the browser; a keyword list asks the question window, see below |
| `restricted` | bool | master-only |
| `visible` | `:active` (default) \| `:archived` \| bool \| **`fn record, state ->`** | arity **2** |
| `js` | `fn record -> %JS{}` | chained onto the click |
| `render` | `fn record ->` / `fn record, action ->` / `fn record, action, target ->` | |
| `open` | `:form` \| `fn record ->` / `fn record, state ->` | `:drawer`; what the drawer shows |
| `drawer` | keyword list | `:drawer`; the drawer's head, see below |

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

`visible` and `restricted` decide which rows expand, as they decide which rows show any other
action: the caret is drawn only on a row whose accordion is visible for that record. The caret
column stays while some row may expand, so the other rows keep their columns.

## `confirm` — the browser's question or the question window

A string (or `fn record -> string`) is the browser's own question, through `data-confirm`. A
keyword list is asked in the UI adapter's `question/1` window instead, drawn by the table on the
server, with no JavaScript: a title, a sentence, a tone, its own button words and, with `answer`,
a field the reader types a word into before the button answers. Each value but `tone` is a string,
translated, or `fn record -> string`:

```elixir
action :delete, type: :destroy,
  confirm: [
    title: fn product -> "Delete #{product.name}?" end,
    body: "Its files and its sales history are deleted with it.",
    tone: :danger,                                   # :danger (default) | :warn | :info
    answer: fn product -> product.name end,          # type the name to confirm
    answer_label: "Type the product's name",         # default: "Type <answer> to confirm"
    confirm_label: "Delete product",                 # default: "Confirm"
    cancel_label: "Keep it"                          # default: "Cancel"
  ]
```

The press asks and runs nothing. The window's button runs the very event the button would have
sent, with its values; Cancel, the backdrop and Escape run nothing. A wrong answer is refused under
the field, "Type “Lamp” exactly as it is written.", and runs nothing. The table reads the row again
as it asks, so a row that is gone asks nothing. The window's id is `"<table id>-question"`, drawn
by `Shared.render_overlays/1`. Every built-in type that asks takes it: `:event`, `:edit`,
`:destroy`, `:update`, `:unarchive`, `:permanent_destroy`; a custom `ActionType` puts it on its
button with `MishkaGervaz.Question.bind/4`
([../customization/types.md](../customization/types.md)).

## `:drawer`

Opens the row in the table's drawer, the UI adapter's `drawer/1` (or `sheet/1` with
`kind: :sheet`), without leaving the page. `open` is what it shows: a record view,
`fn record -> ~H"…" end`, or `:form`, the resource's own form editing the row. `drawer` builds its
head from the row; each value but `kind` and `actions_at` is a value or `fn record -> value end`:

```elixir
action :view, type: :drawer,
  open: &MyAppWeb.OrderViews.order/1,
  drawer: [
    title: fn order -> order.number end,
    sub: fn order -> order.customer_name end,
    icon: "hero-receipt-percent",
    tone: :info,                                   # :info | :ok | :warn | :danger | :mute
    chips: fn order -> [{:ok, "Paid"}, order.provider] end,
    actions: &MyAppWeb.OrderViews.order_actions/1, # buttons, fn record -> ~H"…" end
    actions_at: :foot                              # or :head
  ]

action :edit, type: :drawer, open: :form, drawer: [kind: :sheet, title: "Edit order"]
```

The table reads the row again by its id as the drawer opens, under its own read action and tenant;
a row that is gone opens nothing. The drawer's id is `"<table id>-row-drawer"` and its close button
closes it. With `open: :form` the form is `MishkaGervaz.Form.Web.Live` with the id
`"<table id>-drawer-form"`; it tells the page `{:form_saved, mode, record}`, and the page closes the
drawer and puts the saved row back in its place:

```elixir
def handle_info({:form_saved, _mode, record}, socket) do
  MishkaGervaz.Table.Web.Live.close_drawer("orders-table", record)
  {:noreply, socket}
end
```

A custom template draws the drawer by ending its root element with
`Shared.render_overlays(assigns)` ([../customization/table-templates.md](../customization/table-templates.md)).

## `dropdown`

Contains `action` and `separator` entities. `separator label: "Permanent"` draws a labelled
divider, and only above an action the reader can see, with one before it: a separator whose
actions are all hidden for the row (`visible`, `restricted`) is not drawn. `ui` on the dropdown
itself styles the trigger.

The Tailwind adapter draws the menu as a native popover (`popover`, opened by the trigger's
`popovertarget`), in the browser's top layer, so the table's scrolling frame or a card never clips
it. CSS anchor positioning puts it under its trigger, or above it near the bottom of the screen.
Tab moves from the trigger into its items; a click on an item, a click elsewhere or Escape closes
it. A template that puts the menu inside its own markup inherits none of that markup's clipping,
but CSS it aims at the menu's descendants (such as `[&_button]:…` on a wrapper) still reaches the
menu's items.

## `actions_layout`

Names which actions render inline and which collapse into a dropdown. Every name listed must
exist. `auto_collapse_after N` folds everything past the Nth.

## The Actions column in the plain table

From 980px up `MishkaGervaz.Table.Templates.Table` is one CSS grid, and the header and every row
lay their cells on its columns. The Actions column is a `max-content` track: as wide as the widest
row of controls on the page, header included, with 16px of padding either side. A row streamed in
later widens it like any other.

When rows show different controls, say Run again and Cancel on one and Cancel alone on another, a
`max-content` track changes width as they change and the `fr` columns move with it. `actions_layout`'s
`width` gives the track instead: the width of the most controls a row can show, as a grid track.
With the Tailwind adapter's 30px buttons, 4px apart, two are `"minmax(96px,max-content)"`:

```elixir
actions_layout do
  width "minmax(96px,max-content)"
end
```

With `sticky true` the column is pinned to the frame's right edge and fades the columns scrolling
under it out over 16px on its left. The cell and its fade take the row's `background-color`, so a
`row class`, `theme row_class`, selection or hover colour reaches them too. Both are CSS alone: the
app sets nothing up. Below 980px the rows are cards and none of this applies.

## Rules the compiler enforces

- `type :link` requires `path`, unless the action is named `:show`, `:show_link`, `:edit` or
  `:edit_link`: those build `{route}/{id}` or `{route}/{id}/edit` from `identity`'s route, its
  `:param` segments filled in from `state.path_params`. A `path` still wins when given.
- `type :event` requires `event`.
- `type :drawer` requires `open`.
- A `dropdown` requires a `ui` block **with a `label`** — including for actions nested inside it.

## The action types — compared

| `type` | What it does | Needs | Message to the parent |
|---|---|---|---|
| `:link` | navigates | `path` (or a `:show`/`:edit` name) | — |
| `:event` | fires a custom event | `event` | `{:row_action, event, payload}` |
| `:edit` | opens the resource's form | the form section | none — `send_update`s the form component directly |
| `:destroy` | soft-deletes | `source.actions.destroy` | — |
| `:update` | runs an Ash action | `action` | — |
| `:unarchive` | restores | `source.archive.restore_action` | — |
| `:permanent_destroy` | hard-deletes | `source.archive.destroy_action` | — |
| `:row_click` | makes the whole row clickable | `event` / `path` | as for its shape |
| `:accordion` | declares the row expands | the `on_expand` hook | `{:expand_row, id}` |
| `:modal` | a modal-opening button | your own `js` / `event` | as for its shape |
| `:drawer` | opens the row's view or form in the table's drawer | `open` | none; a form in it sends `{:form_saved, mode, record}` |
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
- [ ] Destructive actions carry `confirm`; one that cannot be taken back asks in the question
  window with an `answer` to type
- [ ] The table declares `source.actions.get` — most of these types need it

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.row_actions`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions) · [`mishka_gervaz.table.row_actions.action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-action) · [`mishka_gervaz.table.row_actions.action.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-action-ui) · [`mishka_gervaz.table.row_actions.actions_layout`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-actions_layout) · [`mishka_gervaz.table.row_actions.dropdown`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-dropdown) · [`mishka_gervaz.table.row_actions.dropdown.action`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-dropdown-action) · [`mishka_gervaz.table.row_actions.dropdown.separator`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row_actions-dropdown-separator)

**Schema:** `MishkaGervaz.Table.Entities.RowAction`, `.RowAction.Ui`, `.RowActionDropdown`,
`.DropdownSeparator` · **Verifier:** `Table.Verifiers.ValidateRowActions` ·
**Types:** `MishkaGervaz.Table.Types.Action`
