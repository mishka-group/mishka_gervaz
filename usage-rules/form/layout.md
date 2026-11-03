# Form → `layout` (mode, grid, steps)

How the form is shaped: one page, a wizard, or tabs — plus the grid and the step definitions.
The `header` / `footer` / `notice` entities also live in this block; they have their own file:
[chrome.md](chrome.md).

```elixir
layout do
  mode :standard          # :standard | :wizard | :tabs
  columns 2               # 1 | 2 | 3 | 4
  navigation :sequential  # :sequential | :free  — :free is INVALID with :wizard
  persistence :none       # :none | :ets | :client_token
  responsive true         # ⚠ compiled but no built-in template reads it
end
```

| Mode | Steps | Behaviour |
|---|---|---|
| `:standard` | **forbidden** | one page, every group visible |
| `:wizard` | **required** | one step at a time, sequential by design |
| `:tabs` | **required** | every step rendered as a tab/accordion; `navigation :free` allowed |

`columns`, `navigation` and `persistence` are inheritable from the domain.

## Steps

```elixir
layout do
  mode :wizard
  columns 2
  navigation :sequential
  persistence :ets

  step :basic_info do
    groups [:general, :metadata]
    action :validate_basic                   # Ash action run when leaving the step
    on_enter     fn state -> state end
    before_leave fn state -> state end        # {:halt, state} BLOCKS navigation
    after_leave  fn state -> state end

    ui do
      label "Basic Information"
      icon "hero-information-circle"
      description "Enter the basic details."
      class "…"
      header_class "…"
    end
  end

  step :review do
    groups [:general]
    summary true                              # at most ONE summary step
  end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `groups` | `[atom]` | — | **required** |
| `summary` | bool | `false` | read-only review step |
| `action` | atom | — | ⚠ not wired — see below |
| `on_enter` / `before_leave` / `after_leave` | `fn state -> state` | — | ⚠ not wired — see below |

### ⚠ Step callbacks are declared but not invoked

`action`, `on_enter`, `before_leave` and `after_leave` compile into `Info.Form.steps/1`, but
`MishkaGervaz.Form.Web.Events.StepHandler` does not call them — navigation goes through
`can_advance?/2`, `advance/2`, `go_back/1` and `goto_step/2`. Verified against
`lib/mishka_gervaz/form/web/`.

To gate navigation today, override `can_advance?/2`:

```elixir
defmodule MyApp.Form.StepHandler do
  use MishkaGervaz.Form.Web.Events.StepHandler

  def can_advance?(state, :details), do: state.field_values[:title] not in [nil, ""]
  def can_advance?(state, step), do: super(state, step)
end
```

```elixir
form do
  events do step MyApp.Form.StepHandler end
end
```

See [../customization/overrides.md](../customization/overrides.md).

`ui`: `label` · `icon` · `description` · `class` · `header_class` · `extra`.

## `persistence`

| Value | Where step data lives between navigations |
|---|---|
| `:none` (default) | nowhere — a reconnect loses it |
| `:ets` | server-side table |
| `:client_token` | signed token on the client |

Choose deliberately: a long wizard with `:none` loses everything on a dropped socket.

## Rules the compiler enforces

1. Steps present iff `mode` is `:wizard` or `:tabs`.
2. `navigation :free` is incompatible with `:wizard` — use `:tabs` for free navigation.
3. Every step `groups` entry names an existing group.
4. No group appears in two steps.
5. At most one step has `summary: true`.

## TODO
- [ ] `mode` matches the presence of steps
- [ ] `navigation :free` only with `:tabs`
- [ ] Every step group exists and appears in exactly one step
- [ ] At most one `summary true`
- [ ] Navigation gating done by overriding `can_advance?/2`, not by `before_leave`
- [ ] `persistence` chosen for the length of the wizard
- [ ] `columns` set here, overridden per group only where it differs

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.layout`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout) · [`mishka_gervaz.form.layout.step`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout-step) · [`mishka_gervaz.form.layout.step.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-layout-step-ui)

- Domain — [`mishka_gervaz.form.layout`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-form-layout)

**Schema:** `MishkaGervaz.Form.Dsl.Layout`, `Form.Entities.Step`, `.Step.Ui` ·
**Verifier:** `Form.Verifiers.ValidateSteps`
