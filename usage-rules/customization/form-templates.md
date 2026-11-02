# Custom form templates

A form **template** answers *where things go*: groups, steps, notices, the submit area. It never
decides how an input looks — that is the [UI adapter](ui-adapters.md).

Built in: `MishkaGervaz.Form.Templates.Standard` (default). It already renders all three layout
modes — `:standard`, `:wizard`, `:tabs` — so you only need your own when the **arrangement**
differs: a sidebar form, a two-pane editor, a form embedded in a card.

```elixir
presentation do
  template MyAppWeb.Forms.SidebarForm
end
```

## Skeleton

`use MishkaGervaz.Form.Behaviours.Template` delegates the four optional callbacks to `Standard`
and marks them overridable. Most custom templates override only `render/1`.

```elixir
defmodule MyAppWeb.Forms.SidebarForm do
  use MishkaGervaz.Form.Behaviours.Template

  @impl true
  def name,  do: :sidebar

  @impl true
  def label, do: "Sidebar"

  @impl true
  def icon,  do: "hero-bars-3"

  @impl true
  def render(assigns) do
    ~H"""
    <aside id={"#{@static.id}-form-wrapper"}>
      …
    </aside>
    """
  end

  # render_loading/1, render_field/1, render_group/1, render_step_indicator/1
  # delegate to Standard. Override any of them as needed.
end
```

## Callbacks

| Callback | Required | Default from `use` |
|---|---|---|
| `name/0` | ✔ | — |
| `label/0` | ✔ | — |
| `icon/0` | ✔ | — |
| `render/1` | ✔ | — |
| `render_loading/1` | — | `Standard.render_loading/1` |
| `render_field/1` | — | `Standard.render_field/1` — dispatches per field type |
| `render_group/1` | — | `Standard.render_group/1` |
| `render_step_indicator/1` | — | `Standard.render_step_indicator/1` |

Implementing the behaviour **bare** (`@behaviour` without `use`) means writing all eight —
`Standard` itself takes that path.

## Assigns the renderer passes

| Assign | Contents |
|---|---|
| `@static` | `MishkaGervaz.Form.Web.State.Static` — id, fields, groups, steps, uploads, submit, ui_adapter, template, theme, features, debounce, layout_mode / layout_columns / layout_navigation, header/footer/notices, `submit_visible?`, `submit_alternatives`. **Same reference always** |
| `@state` | the dynamic state — `form` (a `Phoenix.HTML.Form` built from an `AshPhoenix.Form`), mode, current_step, step_states, wizard_history, field_values, relation_options, combobox_options, errors, form_errors, dirty?, existing_files, upload_state, defaults, dismissed_notices |
| `@myself` | the LiveComponent target |
| `@uploads` | the LiveView uploads map (defaults to `%{}`) |

`@state.static.layout_mode` is what `Standard` dispatches on. When `@state` is absent the renderer
calls `render_loading/1` instead.

## What `render/1` must cover

`Standard` renders in this fixed order, and a replacement should keep it — notice positions are
defined relative to it:

1. notices at `:form_top`
2. header chrome (with `:before_header` / `:after_header` notices)
3. notices at `:before_groups`
4. the body — groups (standard) or the current step's groups (wizard/tabs), with
   `{:before_group, g}` / `{:after_group, g}` notices interleaved, then (standard) the fields no
   group holds, with the `:before_fields` notices ahead of them
5. upload sections
6. notices at `:before_submit`
7. the submit row — respecting `static.submit_visible?` and `static.submit_alternatives`
8. notices at `:form_bottom`, footer chrome, notices at `:form_footer`

Positions and bindings: [../form/chrome.md](../form/chrome.md).

## Field-type dispatch

`render_field/1` dispatches to the modules under `MishkaGervaz.Form.Types.Field.*` for built-in
types, and to any module implementing `MishkaGervaz.Form.Behaviours.FieldType` for custom ones
([types.md](types.md)). Delegate to `Standard.render_field/1` unless the **wrapper** differs — and
if only the wrapper differs, override the adapter's `field_wrapper/1` instead of the template.

## The wrapper id matters

Form `js` hooks are pushed to the browser as a `"gervaz:exec-js"` event targeting
`<component-id>-form-wrapper`. Keep that id on your root element or the JS hooks silently do
nothing.

## Template or adapter? — decide with this table

| Symptom | Change |
|---|---|
| the input, label or error markup is wrong | adapter — `field_wrapper` / `field_error` / the input components |
| the group box is wrong | adapter — `field_group` |
| the step indicator is wrong | adapter — `step_indicator` / `step_navigation` |
| the submit row is wrong | adapter — `button`, or the DSL's `submit ui do … end` |
| **fields sit in the wrong place on the page** | template |
| **the form needs a second pane, a sidebar, or its own scroll region** | template |

## TODO
- [ ] `use MishkaGervaz.Form.Behaviours.Template` rather than implementing all eight
- [ ] `name/0`, `label/0`, `icon/0`, `render/1` implemented
- [ ] Root element carries `id={"#{@static.id}-form-wrapper"}`
- [ ] The eight render stages kept in order, so notice positions still mean something
- [ ] `static.submit_visible?` and `static.submit_alternatives` honoured
- [ ] `render_field/1` left delegating unless the wrapper genuinely differs
- [ ] Config read from `@static`, dynamic values from `@state`
- [ ] An adapter change ruled out first (see the table above)

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Behaviour:** `MishkaGervaz.Form.Behaviours.Template` ·
**Read as the example:** `MishkaGervaz.Form.Templates.Standard` ·
**Bridge:** `MishkaGervaz.Form.Web.Renderer`
