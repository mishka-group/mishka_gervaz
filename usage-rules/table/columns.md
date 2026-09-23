# Table → `columns`

The cells: where each value comes from, whether it sorts, and how it renders.

```elixir
columns do
  column_order [:title, :status, :inserted_at]        # unlisted columns go last
  default_sort [{:featured, :desc}, {:inserted_at, :desc}]

  column :title do
    sortable true
    label fn -> dgettext("mishka_gervaz", "Title") end
    ui do width "minmax(180px,1.8fr)" end
    render fn value -> … end
  end
end
```

`default_sort` **must be a list** of `{field, :asc | :desc}` (a keyword list counts —
`default_sort featured: :desc, inserted_at: :desc`). A bare atom or single tuple is passed through
unchanged and breaks the query. With no `default_sort`, a sortable `:inserted_at` column implies
`[{:inserted_at, :desc}]`; otherwise there is no sort.

## `column :name` options

| Option | Type | Default | Note |
|---|---|---|---|
| `source` | see below | column name | where the value comes from |
| `sortable` | bool | `false` | |
| `searchable` | bool | `false` | ⚠ not wired — see below |
| `filterable` | bool | `false` | ⚠ not wired — see below |
| `visible` | bool \| `fn state ->` | `true` | arity **1** |
| `position` | int \| `:first` \| `:last` \| `{:before, col}` \| `{:after, col}` | — | |
| `export` / `export_as` | bool / atom | `true` / name | ⚠ not wired — see below |
| `default` | any | — | used when the source is nil |
| `separator` | string | `" "` | joins merged sources |
| `static` | bool | `false` | **no DB source** — computed or hardcoded |
| `requires` | `[atom]` | `[]` | the fields a static column reads |
| `sort_field` | `[atom]` | `[]` | DB field(s) to sort by; **required** for `static` + `sortable` |
| `format` | `fn value ->` \| `fn state, record, value ->` | — | transforms the value before render |
| `render` | `fn input ->` \| `fn input, state ->` | — | returns HEEx |
| `label` | string \| `fn -> string` | — | shorthand for `ui.label` |

`source` shapes: `:field` · `{:relation, :field}` · `{:relation, [:f1, :f2]}` · `[:f1, :f2]` ·
`[{:user, :name}, :title]`.

### ⚠ `searchable`, `filterable`, `export`, `export_as` are declared but not wired

All four compile into `Info.Table.columns/1` but **nothing at runtime reads them** — verified
against `lib/mishka_gervaz/table/`. In particular:

- global text search is driven by `filter :search, :text, fields: [:title, :slug]`, **not** by
  `searchable true` on columns ([filters.md](filters.md));
- `filterable true` does **not** create a filter — declare it in `filters do … end`;
- there is no built-in export; `:export` is likewise absent from every template
  ([presentation.md](presentation.md)).

Set them if you want the intent recorded for a custom template to read; do not expect behaviour.

## What `render` receives — the rule people get wrong

- `static: true` **with** a non-empty `requires` → a **map of exactly those fields**.
  `fn record -> record.title end` and `record[:size]` both work; it is a plain map, not the struct.
- anything else → the **formatted cell value** (after `format`), *not* the record:
  `fn value -> … end`.
- arity 2 adds the live `state` as the second argument.

```elixir
column :site_datetime do
  static true
  requires [:site_id, :site, :inserted_at]        # ⇒ render gets %{site_id: …, site: …, inserted_at: …}
  sortable true
  sort_field [:inserted_at]

  render fn record, state ->
    site = if state.master_user?, do: record.site.name, else: state.current_user.site.name
    assigns = %{site: site, date: Calendar.strftime(record.inserted_at, "%b %d, %Y")}
    ~H"<div>{@site} — {@date}</div>"
  end
end
```

## `ui do … end`

`label` · `type` · `width` · `min_width` · `max_width` · `align` (`:left` / `:center` / `:right`) ·
`class` · `header_class` · `extra` (map).

**`ui.type` values with a built-in renderer:** `:text` (default) · `:boolean` · `:number` ·
`:date` · `:datetime` · `:uuid` · `:array` · `:badge` · `:bars` · `:tags` · `:avatars` · `:link`.

The schema also accepts `:currency` `:percentage` `:time` `:image` `:avatar` `:progress` `:json`
`:custom` — **these have no renderer module**. Use them only alongside your own `render`, or point
`type` at a `ColumnType` module ([../customization/types.md](../customization/types.md)).

Type options go in `ui.extra`:

```elixir
ui do
  type :badge
  extra %{
    colors: %{"published" => "bg-green-100 text-green-800", "draft" => "bg-amber-100 text-amber-800"},
    labels: %{"js" => "JavaScript"},
    default_color: "bg-gray-100 text-gray-600"
  }
end

ui do type :bars;    extra %{max: 4, percent: true} end
ui do type :tags;    extra %{max_items: 3} end   # items: strings, or %{label:, class:, title:}
ui do type :avatars; extra %{max_items: 3, label_field: :display_name, tints: %{}} end
```

Inline form works too: `column :inserted_at, sortable: true, visible: false, label: fn -> … end`.

## Five ways to change what a cell shows — compared

They compose in this order, so more than one may apply to the same column.

| Option | Changes | Receives | Returns | Reach for it when |
|---|---|---|---|---|
| `source` | **which value** is read | — | — | the value lives on a relationship, or is several fields joined |
| `default` | the value **when the source is nil** | — | any | an empty cell should read as something |
| `format` | the value **before rendering** | `value`, or `state, record, value` | any | a pure transform — bytes → "1.2 MB", cents → money |
| `ui.type` | **how** the value is drawn | value, column, record, adapter | HEEx | a shape that repeats — badge, tags, bars, avatars |
| `render` | the **whole cell** | the static-`requires` map, or the formatted value (+ `state`) | HEEx | this cell is genuinely bespoke |

Precedence at render time: `render` wins over `ui.type`, which wins over the plain value. `format`
runs **before** all three. `source` and `default` run before `format`.

So: reach for `format` before `render` when the change is textual, and for `ui.type` before
`render` when the shape repeats — a `render` is markup you now own forever.

`static` / `requires` / `sort_field` are a separate triad about **where the data comes from**, not
how it looks: `static true` says "not a DB column", `requires` says "but I read these fields", and
`sort_field` says "sort by these instead".

## `auto_columns`

```elixir
columns do
  auto_columns do
    except [:id, :archived_at]          # or: only [:name, :status]
    position :end                        # :start | :end
    defaults do sortable true; searchable false; visible true; export true end
    ui_defaults do
      boolean_true_label "Yes"
      boolean_false_label "No"
      datetime_format :medium
      text_truncate 40
    end
    override :inserted_at, sortable: true
    override :bio do ui do label "Biography" end end
  end
end
```

Discovered from the resource's public Ash attributes and merged with explicit `column`
declarations, which keep their own positions.

## TODO
- [ ] `static true` paired with `requires`
- [ ] `static` + `sortable` paired with `sort_field`
- [ ] `render`'s first argument matches the static rule above (map vs value)
- [ ] `ui.type` is renderer-backed, or the column supplies `render`
- [ ] `default_sort` is a list
- [ ] `visible fn` has arity **1**
- [ ] Labels via `fn -> dgettext("mishka_gervaz", "…") end`
- [ ] `ui.extra` keys read from the type module that consumes them

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.columns`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns) · [`mishka_gervaz.table.columns.column`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns-column) · [`mishka_gervaz.table.columns.column.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns-column-ui) · [`mishka_gervaz.table.columns.auto_columns`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns-auto_columns) · [`mishka_gervaz.table.columns.auto_columns.defaults`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns-auto_columns-defaults) · [`mishka_gervaz.table.columns.auto_columns.ui_defaults`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns-auto_columns-ui_defaults) · [`mishka_gervaz.table.columns.auto_columns.override`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-columns-auto_columns-override)

**Schema:** `MishkaGervaz.Table.Entities.Column`, `.Column.Ui`, `.AutoColumns` ·
**Verifier:** `Table.Verifiers.ValidateColumns` · **Types:** `MishkaGervaz.Table.Types.Column`
