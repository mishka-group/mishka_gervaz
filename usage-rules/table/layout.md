# Table → `layout` (chrome)

The header, footer and notices drawn around the table. Mirrors the form's `layout` chrome — same
option names, different positions.

```elixir
layout do
  header do
    title "Pages"
    description "All published and draft pages."
    icon "hero-document-text"
    class "mb-6"
    visible fn state -> … end
    restricted false
    render fn assigns -> ~H"…" end          # or fn assigns, state ->
    extra %{}
  end

  footer do
    content fn state -> "Sorted by priority." end     # string | fn -> | fn state ->
    class "mt-2 text-[11px] text-[#a8a5a0]"
  end

  notice :archived_warning do
    position :before_table
    type :warning
    icon "hero-archive-box"
    title "Viewing archived records"
    bind_to :archived_view
    dismissible false
    show_when fn state -> … end
    ui do class "…" end
  end
end
```

## `header` / `footer`

`title` / `content` / `description` accept a string, `fn -> string`, or `fn state -> string`.
`visible` and `restricted` are arity **1**. `render` replaces the whole thing with HEEx
(`fn assigns ->` or `fn assigns, state ->`).

## `notice` positions

`:table_top` · `:before_header` · `:after_header` · `:before_filters` · `:after_filters` ·
`:before_bulk_actions` · `:after_bulk_actions` · `:before_table` · `:after_table` ·
`:before_pagination` · `:after_pagination` · `:table_bottom` · `:empty_state` ·
`{:before_column, :name}` · `{:after_column, :name}`.

An invalid position fails the build with the list of valid ones. `{:before_column, …}` must name a
declared column.

## `notice` bind_to

| `bind_to` | Renders while |
|---|---|
| `:no_results` | the page the last load read came back empty |
| `:has_filters` | any filter has a non-empty value |
| `:has_selection` | any row is selected |
| `:loading` | the table is loading |
| `:error` | the load returned an error |
| `:archived_view` | the reader is viewing archived records |
| *(omitted)* | controlled solely by `visible` / `show_when` |

`bind_to` and `show_when` combine with **AND**. `type` is `:info` (default) / `:warning` /
`:error` / `:success` / `:neutral`. `dismissible true` lets the reader close it — dismissal is
tracked per notice `name` in `state.dismissed_notices`.

## TODO
- [ ] Notice names unique within the table
- [ ] `position` copied from the list above, not guessed
- [ ] `{:before_column, …}` names a declared column
- [ ] `bind_to` used instead of hand-writing the same condition in `show_when`
- [ ] `dismissible` only where never showing it again is acceptable
- [ ] Header/footer text via `dgettext`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.layout`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-layout) · [`mishka_gervaz.table.layout.header`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-layout-header) · [`mishka_gervaz.table.layout.footer`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-layout-footer) · [`mishka_gervaz.table.layout.notice`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-layout-notice) · [`mishka_gervaz.table.layout.notice.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-layout-notice-ui)

**Schema:** `MishkaGervaz.Table.Entities.Header`, `.Footer`, `.Notice`, `.Notice.Ui` ·
**Verifier:** `Table.Verifiers.ValidateLayout`
