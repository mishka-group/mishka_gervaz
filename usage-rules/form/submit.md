# Form → `submit`

The create / update / cancel / discard buttons. An entity, not a section — one singleton block
holding the button sub-entities, a shared `ui`, and a `position`.

```elixir
submit do
  create label: fn -> dgettext("mishka_gervaz", "Create") end
  update label: fn -> dgettext("mishka_gervaz", "Save Changes") end
  cancel label: fn -> dgettext("mishka_gervaz", "Cancel") end
  position :bottom            # :top | :bottom | :both

  ui do
    submit_class "bg-blue-600 text-white"
    cancel_class "bg-gray-200"
    wrapper_class "flex gap-4"
  end
end
```

Block form per button, when you need predicates:

```elixir
submit do
  create label: "Create Item", restricted: true

  update do
    label "Save Item"
    disabled   fn state -> not state.dirty? end
    restricted fn state -> not state.master_user? end
    visible    fn state -> true end
    active true                # false SUPPRESSES a button inherited from the domain
  end

  cancel label: "Go Back", visible: false
end
```

| Button option | Type | Default | Note |
|---|---|---|---|
| `label` | string \| `fn -> string` | per-kind default | `"Create"` / `"Save Changes"` / `"Cancel"` / `"Discard"` |
| `confirm` | string \| `fn -> string` \| keyword list | — | asked before the button acts (`data-confirm`); on `cancel` and `discard` only while the form holds changes. On `create` and `update` a keyword list asks in the question window, below |
| `active` | bool \| `fn state ->` | `true` | `false` drops an inherited button — resource only |
| `disabled` | bool \| `fn state ->` | `false` | |
| `restricted` | bool \| `fn state ->` | `false` | master-only |
| `visible` | bool \| `fn state ->` | `true` | |

All predicates are arity **1** (`state`).

## Cancel

`cancel` with an `on_cancel` hook runs the hook, sends the page `{:form_cancelled, resource}` and
returns the form to an empty create form. Without the hook it is safe to press on an edit: the form
puts back the record's saved values and stays on the record, on the step or tab it is on; a create
starts over empty. Nothing is saved.

## Discard

`discard` draws a button beside Save while the form holds changes (`state.dirty?`). It puts the
form back to its starting values: an edit reads its record again, a create starts over empty with
its `defaults`, the pending uploads are cancelled, and a `:tabs` form stays on its tab. Nothing is
saved. Without a `discard` block there is no such button; a page can do the same with
`MishkaGervaz.Form.Web.Live.discard/1`.

A typed change holds changes only while what the form holds differs from what it held as the
first change arrived: text typed and put back, or a box ticked and unticked again, holds none, so
Discard goes away and Cancel and Discard ask nothing. A file waiting on an upload always counts.

```elixir
submit do
  cancel confirm: fn -> dgettext("mishka_gervaz", "Discard your changes?") end
  discard label: fn -> dgettext("mishka_gervaz", "Discard") end,
          confirm: fn -> dgettext("mishka_gervaz", "Discard your changes?") end
end
```

`confirm` is asked through the button's `data-confirm`, which the host's `phoenix_html` script
answers with the browser's confirm dialog.

### Asking in the question window

On `create` and `update`, a `confirm` given as a keyword list is asked in the UI adapter's question
window before the save, drawn by the form under its `<form>` (id `"<form id>-question"`): the same
keys as a row action's ([../table/row-actions.md](../table/row-actions.md)), a function given the
record the form edits (`nil` on create). The save waits; the window's button saves the values the
form was submitted with, and Cancel saves nothing and keeps what was typed.

```elixir
submit do
  update confirm: [
           title: "Publish the changes?",
           body: fn product -> "Buyers of #{product.name} see them at once." end,
           tone: :warn,
           confirm_label: "Publish"
         ]
end
```

## Inheritance is per button, not per block

| Resource declares | Result |
|---|---|
| no `submit` block | the whole domain submit is inherited |
| a partial block | declared buttons override; missing ones fall back to the domain |
| `create do active false end` | that button is suppressed even though the domain defines it |
| an **empty** `submit do end` | **nothing renders** — a deliberate "no buttons" signal |

`position` and `ui` follow resource → domain → `:bottom` / `nil`.

Put the three default labels on the domain once; declare `submit` on a resource only where it
genuinely differs.

## A refused save

A refused save shows each error on the field it concerns, and the rest above the submit row. Each
message is translated in the host's `errors` Gettext domain, its placeholders filled after. One above
the submit row that is not a whole sentence follows its field's form field or column label. See
`MishkaGervaz.Form.Web.Events.SubmitHandler.save_errors/2` and `MishkaGervaz.Errors`.

## Mount-time overrides

A mount can suppress or extend the submit row without touching the DSL — `submit={false}`,
`submit_alternatives={[…]}`. See [../mounting.md](../mounting.md).

## TODO
- [ ] Domain declares the three labels once
- [ ] Resource-level `submit` only where it differs
- [ ] `active: false` used to drop an inherited button rather than re-declaring the block
- [ ] An empty `submit do end` is intentional, not an accident
- [ ] Predicates are arity **1**
- [ ] Labels via `dgettext`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.submit`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-submit) · [`mishka_gervaz.form.submit.create`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-submit-create) · [`mishka_gervaz.form.submit.update`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-submit-update) · [`mishka_gervaz.form.submit.cancel`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-submit-cancel) · [`mishka_gervaz.form.submit.discard`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-submit-discard) · [`mishka_gervaz.form.submit.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-submit-ui)

- Domain — [`mishka_gervaz.form.submit`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-form-submit) · [`mishka_gervaz.form.submit.create`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-form-submit-create)

**Schema:** `MishkaGervaz.Form.Dsl.Submit`, `Form.Entities.Submit`, `.Submit.Button`,
`.Submit.Ui` · **Merge logic:** `MishkaGervaz.Form.SubmitMerger`
