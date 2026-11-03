# Form → chrome (`header`, `footer`, `notice`)

Declared inside `layout do … end`, alongside the mode and steps ([layout.md](layout.md)).
Mirrors the table's chrome — same option names, different positions and bindings.

```elixir
layout do
  header do
    title "Account Permissions"
    description "Configure what this account can access."
    icon "hero-shield-check"
    class "mb-6"
    visible fn state -> state.mode == :update end
    restricted false
    render fn assigns -> ~H"…" end          # or fn assigns, state ->
    extra %{}
  end

  footer do
    content fn state -> "Last updated by #{state.field_values[:updated_by]}" end
    class "mt-4 text-xs text-gray-500"
  end

  notice :read_only_banner do
    position :before_fields
    type :warning
    title "Read-Only Access"
    content "Your role can view but not modify these settings."
    icon "hero-lock-closed"
    visible fn state -> not state.master_user? end
    dismissible false
  end

  notice :validation_summary do
    position :form_top
    type :error
    bind_to :validation
    title fn _state -> "Please fix the errors below" end
    only_steps [:basics, :content]
  end
end
```

## `header` / `footer`

`title` / `description` / `content` accept a string, `fn -> string`, or `fn state -> string`.
`visible` and `restricted` are arity **1**. `render` replaces the whole thing
(`fn assigns ->` or `fn assigns, state ->`). `extra` is a free map for the template.

## `notice` positions

`:form_top` · `:before_header` · `:after_header` · `:before_groups` · `:before_fields` ·
`:before_submit` · `:form_bottom` · `:form_footer` · `{:before_group, :name}` ·
`{:after_group, :name}`.

An invalid position fails the build with the list of valid ones. `{:before_group, …}` must name a
declared group. `:before_fields` sits before the fields no group holds — every field of a form
without groups, or the ungrouped ones after a grouped form's groups — so a form whose every field
is in a group never draws it.

## `notice` bind_to

| `bind_to` | Renders while |
|---|---|
| `:validation` | `state.form_errors != []` |
| `:uploads` | any registered upload has errors |
| `:dirty` | `state.dirty? == true` |
| *(omitted)* | controlled solely by `visible` / `show_when` |

`bind_to` and `show_when fn state -> boolean end` combine with **AND**.
`type`: `:info` (default) · `:warning` · `:error` · `:success` · `:neutral`.
`only_steps [:a, :b]` scopes a notice to named wizard/tabs steps — the names must exist.
`dismissible true` lets the reader close it; dismissal is tracked per `name` in
`state.dismissed_notices`.

## Rules the compiler enforces

- Notice names are unique within the form.
- Positions are valid atoms or `{:before_group, name}` / `{:after_group, name}`.
- `only_steps` names existing steps.

## TODO
- [ ] Notice names unique
- [ ] `position` copied from the list above, not guessed
- [ ] `{:before_group, …}` names a declared group
- [ ] `bind_to` used instead of re-deriving the same condition in `show_when`
- [ ] `only_steps` used on notices that make sense on one step only
- [ ] `restricted` / `visible` predicates are arity **1**
- [ ] Titles and content via `dgettext`

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.layout.header`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout-header) · [`mishka_gervaz.form.layout.footer`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout-footer) · [`mishka_gervaz.form.layout.notice`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout-notice) · [`mishka_gervaz.form.layout.notice.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout-notice-ui)

**Schema:** `MishkaGervaz.Form.Entities.Header`, `.Footer`, `.Notice`, `.Notice.Ui` ·
**Verifier:** `Form.Verifiers.ValidateChrome`
