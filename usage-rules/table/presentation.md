# Table → `presentation`

Template vs UI adapter, which features are on, theme, responsive behaviour, template switching.

```elixir
presentation do
  template MyAppWeb.Templates.PostCard              # default MishkaGervaz.Table.Templates.Table
  switchable_templates [MishkaGervaz.Table.Templates.Table, MyAppWeb.Templates.PostCard]
  template_options columns: 3
  ui_adapter MyAppWeb.UIAdapters.Admin              # default MishkaGervaz.UIAdapters.Tailwind
  ui_adapter_opts component_module: MyAppWeb.Components
  features :all
  filter_mode :inline                               # :inline | :sidebar | :modal | :drawer
  keep_loaded_records false

  theme do
    header_class "…"
    row_class "…"
    border_class "…"
    extra %{}
  end

  responsive do                    # ⚠ compiled but not read — see below
    hide_on_mobile [:inserted_at]
    hide_on_tablet [:excerpt]
    mobile_layout :cards           # :cards | :stacked
  end
end
```

> ⚠ The whole `responsive` block lands in `Info.Table.config/1` but **no built-in template reads
> it**. Hide columns per breakpoint with `ui do class "max-md:hidden" end` on the column, or read
> `config[:presentation][:responsive]` from a custom template.

## Template vs UI adapter — two orthogonal axes

- **Template** decides *where* things go: rows and columns, cards, a gallery, grouped sections.
- **UIAdapter** decides *how* they look: the button, the select, the badge.

Swapping one never forces the other. Writing either:
[../customization/table-templates.md](../customization/table-templates.md) ·
[../customization/ui-adapters.md](../customization/ui-adapters.md).

Built in: `MishkaGervaz.Table.Templates.Table` (default) and
`MishkaGervaz.Table.Templates.MediaGallery`.

## `features`

The schema accepts `:sort` · `:filter` · `:select` · `:bulk_actions` · `:paginate` · `:export` ·
`:expand` · `:reorder` · `:inline_edit`. `:all` (default) means "whatever the template supports";
a list narrows it; `[]` disables everything.

**The built-in templates only check six of them** — `:sort`, `:filter`, `:select`,
`:bulk_actions`, `:paginate`, `:expand`. `:export`, `:reorder` and `:inline_edit` are accepted and
compiled, but nothing in `Table` or `MediaGallery` renders them, so listing them changes nothing.
A custom template is free to honour them ([../customization/table-templates.md](../customization/table-templates.md)).

## `template_options`

Passed straight to the template. **Read the template's `default_options/0` for the real list** —
a key it does not consume is silently ignored.

| Template | Key | Default | Consumed? |
|---|---|---|---|
| `Table` | `:striped` | `false` | ✔ zebra rows |
| `Table` | `:hoverable` | `true` | ✔ row hover |
| `Table` | `:show_header` / `:bordered` / `:compact` | `true` / `false` / `false` | declared in `default_options/0` but **not read** by the current markup |
| `MediaGallery` | `:columns` | `6` | ✔ sets the card-width floor (`≤3` ⇒ wider cards) |
| `MediaGallery` | `:overlay_action` | `:toggle_featured` | ✔ the row action drawn as the star over the thumbnail |
| `MediaGallery` | `:primary_action` | `:edit` | ✔ the one wide, labelled button |
| `MediaGallery` | `:class` | — | ✔ appended to the grid container |

```elixir
template_options [columns: 3, overlay_action: :pin, primary_action: :open]
```

`MediaGallery` uses the **first visible column's rendered value as the thumbnail URL**. Column
order and `visible` are how you choose it.

## `switchable_templates`

Two or more modules enables the runtime switcher. Keep `template` inside the list. Templates are
compared in `visible` predicates by module or by `state.template.name()`:

```elixir
column :stats, do: visible fn state -> state.template.name() == :table end
```

Add `:template` to `url_sync.params` to make the choice bookmarkable.

## `keep_loaded_records`

Off by default. On, every loaded page accumulates in `state.loaded_records`. Each load reads every
row loaded so far, in as many reads as the read action's `max_page_size` needs, so load-more goes on
past that size without raising it. A reload at a URL page needs no `keep_loaded_records`: every
`:load_more` or `:infinite` table opens page N with every row up to it (see
[pagination.md](pagination.md)).

Turn it on **only** for a template that *groups* rows — section headings, date buckets, category
bands. A LiveView stream is one flat appending container and cannot express a heading, so such a
template cannot render from `@streams`; with `:load_more` or `:infinite` it would otherwise only
ever see the newest page. The cost is holding every loaded row in the LiveView's memory, which is
exactly what streams exist to avoid.

## TODO
- [ ] `template` is a member of `switchable_templates` when switching is offered
- [ ] `keep_loaded_records` only for grouped templates
- [ ] `template_options` keys read from the template module, not guessed
- [ ] `features` narrowed only where a feature must genuinely be off
- [ ] `ui_adapter` is the app's adapter, not the Tailwind default, once you have components
- [ ] `responsive.hide_on_mobile` names real columns

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.presentation`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-presentation) · [`mishka_gervaz.table.presentation.theme`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-presentation-theme) · [`mishka_gervaz.table.presentation.responsive`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-presentation-responsive)

- Domain — [`mishka_gervaz.table.theme`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-theme)

**Schema:** `MishkaGervaz.Table.Dsl.Presentation` ·
**Behaviours:** `MishkaGervaz.Table.Behaviours.Template`, `MishkaGervaz.Behaviours.UIAdapter`
