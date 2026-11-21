# Form → `groups`

Bundles fields into named, layout-aware units. Groups are also the unit a wizard/tabs **step**
references, so the hierarchy reads step → groups → fields.

```elixir
groups do
  group :basic_info do
    fields [:title, :slug, :status]         # required
    collapsible true
    collapsed false
    position :first
    visible fn state -> … end
    restricted false

    ui do
      label fn -> dgettext("mishka_gervaz", "Basic Information") end
      icon "hero-pencil"
      description "Core fields"
      class "border p-4"
      header_class "…"
      columns 2                              # 1..4 — overrides layout.columns for this group
    end
  end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `fields` | `[atom]` | — | **required** |
| `collapsed` | bool | `false` | |
| `collapsible` | bool | `false` | whether the reader may toggle it |
| `visible` / `restricted` | bool \| `fn state ->` | `true` / `false` | arity **1** |
| `position` | int \| `:first` \| `:last` | — | |

`ui`: `label` · `icon` · `description` · `class` · `header_class` · `columns` (1..4) · `extra`.

## Groups partition fields

Compile fails if a group names a field that does not exist, or if one field appears in two groups.
A field in **no** group still renders — as an ungrouped field — but a wizard step can only reach it
through a group, so in `:wizard` / `:tabs` mode every field needs one.

## Grid

`layout do columns N end` sets the default grid; `ui do columns N end` overrides it per group;
`ui do span N end` on a field makes one input straddle several columns. Set the group's columns
rather than repeating `span` on every field.

## Groups in the page's own cards

A page that wants a group in a card of its own, with its own markup between groups, mounts the form
with a `:body` slot and draws each group with `MishkaGervaz.Form.Web.Live.group/1`. It stays one
form, one save. See [../mounting.md](../mounting.md), "Placing the groups in the page".

## TODO
- [ ] Every field belongs to exactly one group (mandatory in wizard/tabs mode)
- [ ] No field listed twice
- [ ] `ui.columns` set per group where the global grid is wrong
- [ ] `collapsible true` wherever `collapsed true` is set
- [ ] `restricted true` on groups that are wholly master-only, instead of on each field
- [ ] Labels via `dgettext`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.groups`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-groups) · [`mishka_gervaz.form.groups.group`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-groups-group) · [`mishka_gervaz.form.groups.group.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-groups-group-ui)

**Schema:** `MishkaGervaz.Form.Entities.Group`, `.Group.Ui` ·
**Verifier:** `Form.Verifiers.ValidateGroups`
