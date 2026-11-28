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
| `:tabs` | **required** | the steps are tabs; `navigation :free` allowed — see below |

`columns`, `navigation` and `persistence` are inheritable from the domain.

## Tabs

A `:tabs` form draws its steps as a `tablist` over the panels, each tab a button sending
`goto_step`; a step's `ui` `label` and `icon` are its tab's. Every panel stays in the form, so what
is typed on one tab is kept while another is open, and the save sends it all.

| `navigation` | Tabs | Submit row |
|---|---|---|
| `:free` | any tab opens | Save on every tab, and Enter in a field saves; no Back or Next |
| `:sequential` (default) | only the tabs already visited open | Back and Next, Save on the last tab only, as a wizard |

A save runs the form's `before_save` and the action as any save does. One that fails on a field of
another tab moves to the first tab holding an error, marks every tab holding one (the adapter
draws a dot, `data-role="gervaz-step-error"`) and sends the page `{:put_flash, :error, message}`
naming the tab; the mark goes once the tab's fields show no error.

```elixir
layout do
  mode :tabs
  navigation :free

  step :basics do
    groups [:basics]
    ui do label "Basics" end
  end

  step :pricing do
    groups [:pricing]
    ui do label "Pricing"; icon "hero-banknotes" end
  end
end
```

## The page's markup in a step

A page adds its own markup to one step of a `:wizard` or `:tabs` form with an `:in_step` slot
naming the step. Each entry is drawn in that step's panel after its groups, shows and hides with
the step, and is given the form as the `:body` slot is:

```heex
<.live_component module={MishkaGervaz.Form.Web.Live} id="post-form" resource={MyApp.Post}
  current_user={@current_user} record_id={@post_id}>
  <:in_step :let={form} name={:content}>
    <.attachments :if={form.state.mode == :update} post_id={@post_id} />
  </:in_step>
</.live_component>
```

- Several entries may name one step; they are drawn in their order.
- It is inside the one `<form>`: no `<form>` of its own, no named input that is not the form's; its
  events go to the page unless they name a `phx-target`.
- A name the form has no step for raises. A `:standard` form ignores the slot (it has `:body`).

## What the page chooses

The page that mounts a `:wizard` or `:tabs` form decides three things about its steps
(`MishkaGervaz.Form.Web.Live`, "Steps the page chooses"):

| Assign | Effect |
|---|---|
| `navigation` | `:sequential` or `:free` in place of the resource's; `:free` on a `:wizard`, or any other value, raises. A later render with another value switches the form over |
| `step` | opens the form on that step (an atom, or its string from a URL); with `:sequential` the steps before it count as done. An unknown name leaves the first step. Applied when it changes from what the page passed before, or the form starts over |
| `notify_step` | `true` sends the page `{:form_step, id, step}` each time the form moves to another step |

One resource can then be a step-by-step `:tabs` form while a record is made and free tabs once it
exists, with the step kept in the URL:

```heex
<.live_component module={MishkaGervaz.Form.Web.Live} id="post-form" resource={MyApp.Post}
  current_user={@current_user} record_id={@post_id}
  navigation={if @post_id, do: :free, else: :sequential}
  step={@step} notify_step={true} />
```

```elixir
def handle_info({:form_step, "post-form", step}, socket),
  do: {:noreply, push_patch(socket, to: ~p"/posts/new?step=#{step}")}
```

Handing the step back as `step` leaves the form where it is; a render that passes the same value
again does not move it.

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
| `save` | bool | `false` | Next on this step saves — see "A step that saves" |
| `action` | atom | — | ⚠ not wired — see below |
| `on_enter` / `before_leave` / `after_leave` | `fn state -> state` | — | ⚠ not wired — see below |

### A step that saves

`save true` makes Next on the step save what the form holds, as the last step's submit does: the
first such save creates the record, the later ones update it. A reader who leaves half way keeps a
draft, and a step can show what only a saved record has (its files, its prices) through the
`:in_step` slot.

- The save runs once the step's own fields hold no error. A save the action refuses stays on the
  step with its errors, or moves to the earlier step holding one.
- A save that succeeds sends the page `{:form_saved, mode, record}` (`:create` first, `:update`
  after) and opens the saved record for editing on the next step, in update mode.
- A page that passes `record_id` sets it from `{:form_saved, :create, record}`, or its next render
  takes the form back to create.
- Only where Next exists: a wizard, or tabs with `navigation :sequential`. On free tabs every save
  saves already; on the last step the flag is the save it makes anyway.
- Any update save of a form mounted with `record_id` keeps the step or tab it was made on.

```elixir
step :basics do
  groups [:basics]
  save true
end
```

```elixir
def handle_info({:form_saved, :create, post}, socket),
  do: {:noreply, assign(socket, :post_id, post.id)}
```

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
