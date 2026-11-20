# Table → `row`

Selection, row click, a path the whole row opens, per-row classes, and whole-row replacement.

```elixir
row do
  selectable true                       # checkboxes — this makes source.actions.get REQUIRED
  event "row_clicked"
  payload fn record -> %{id: record.id} end
  path fn record -> ~p"/admin/products/#{record.id}" end

  class do
    apply fn record -> if record.featured, do: "bg-[#fdf9ec]" end
    possible ["bg-[#fdf9ec]"]           # so Tailwind's JIT keeps the class
  end

  override do
    component MyAppWeb.CustomRow                     # a LiveComponent, or:
    render fn assigns, record, columns -> ~H"…" end
    condition fn record -> record.pinned end          # override applies only when true
  end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `selectable` | bool | `false` | declares intent — see the note below |
| `event` | string | — | event name fired on row click |
| `payload` | map \| `fn record -> map` | — | what the click sends |
| `path` | `fn record -> path` \| `fn record, state -> path` | — | the path the whole row opens; `nil` for a row that opens none |
| `class.apply` | `fn record -> class \| nil` | — | per-row class |
| `class.possible` | `[string]` | `[]` | every class `apply` can return |
| `override.component` | module | — | replaces the whole row |
| `override.render` | `fn assigns, record, columns -> HEEx` | — | |
| `override.condition` | `fn record -> boolean` | — | |

`class.possible` exists because Tailwind scans source files, not runtime values — a class only
`apply` ever produces is otherwise stripped from the build. Nothing reads it at runtime, and that
is the point: it puts the literal in a file the scanner will read.

## A row that opens a path

With `path`, the default table template draws a link over each row to the path its function gives,
so a click anywhere on the row opens it (a LiveView `navigate`). The link is reached with Tab and
opened with Enter, and reads as the row's first column to a screen reader (its value when it is
text or a number, "Open" otherwise). The row's checkbox, caret and actions stand above the link and
keep their own clicks; a link or button inside a cell is under it, so give such a table's rows no
`path`. A custom template reads the path with `MishkaGervaz.Table.Templates.Shared.row_path/3`.

## ⚠ What actually draws the checkboxes

The built-in templates decide by **feature and bulk actions**, not by `selectable`:

```elixir
show_checkboxes = :select in features and bulk_actions != [] and has_a_visible_bulk_action?
```

So a table gets checkboxes when `presentation.features` includes `:select` (the `:all` default
does) **and** `bulk_actions` declares at least one action visible in the current archive scope.

`selectable true` still matters for two reasons: it is what the verifier reads to make
`source.actions.get` required, and it records the intent for a custom template. Declare it
alongside your bulk actions — just do not expect it alone to produce checkboxes.

## TODO
- [ ] Every class `apply` can return is also listed in `possible`
- [ ] `selectable true` accompanied by a `get` action in `source.actions`
- [ ] `override.condition` set, unless the override really is for every row
- [ ] Row click and row actions do not both claim the same gesture
- [ ] `path` only on a table whose cells hold no links or buttons of their own

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.row`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row) · [`mishka_gervaz.table.row.class`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row-class) · [`mishka_gervaz.table.row.override`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-row-override)

**Schema:** `MishkaGervaz.Table.Dsl.Row`, `MishkaGervaz.Table.Entities.RowOverride`
