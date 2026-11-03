# MishkaGervaz — Customization

Five independent layers. Reach for the **lowest** one that solves the problem — each step down
costs more code to maintain.

| # | Layer | Change it when | Rules |
|---|---|---|---|
| 1 | **DSL options** | a value, a label, a class, a predicate | [table.md](table.md) · [form.md](form.md) |
| 2 | **`render` / `format` on one entity** | one table cell renders differently | [table/columns.md](table/columns.md) |
| 3 | **A custom type** | that rendering repeats across resources | [customization/types.md](customization/types.md) |
| 4 | **A UI adapter** | every button / select / badge should look like your design system | [customization/ui-adapters.md](customization/ui-adapters.md) |
| 5 | **A template** | the *arrangement* differs — cards, a gallery, grouped sections, a sidebar form | [customization/table-templates.md](customization/table-templates.md) · [customization/form-templates.md](customization/form-templates.md) |
| 6 | **A builder / handler / loader** | the behaviour itself differs — how records load, how events dispatch | [customization/overrides.md](customization/overrides.md) |

Behaviour hooks are a separate axis: [table/hooks.md](table/hooks.md) ·
[form/hooks.md](form/hooks.md).

## Template vs UI adapter — the one distinction to keep straight

```
Template   = WHERE things go   — rows and columns, cards, a gallery, steps, a sidebar
UIAdapter  = HOW they look     — the button, the select, the badge, the cell
```

They are orthogonal. Swapping the template never forces a new adapter; swapping the adapter never
forces a new template. `MishkaGervaz.Table.Templates.MediaGallery` and
`MishkaGervaz.UIAdapters.MediaGallery` are a *pair* by convention only — the template asks for the
adapter when the resource has not named one of its own.

## Everything is overridable, and the DSL is how you wire it

```elixir
mishka_gervaz do
  form do
    events do submit MyApp.Form.SubmitHandler end
    state  do field  MyApp.Form.FieldBuilder end
    data_loader do relation MyApp.Form.RelationLoader end
  end

  table do
    presentation do
      template MyAppWeb.Templates.PostCard
      ui_adapter MyAppWeb.UIAdapters.Admin
    end
  end
end
```

The override module is read **at runtime** from the compiled config — there is no macro tree to
recompile, and `super` always reaches the default implementation.

## TODO — before writing any custom module
- [ ] Checked whether a DSL option already answers it
- [ ] Checked whether `render` / `format` on the one entity is enough
- [ ] Chosen the lowest layer that works
- [ ] The new module is wired through the DSL, not hard-coded at the call site
- [ ] `super` used rather than re-implementing the default

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`
