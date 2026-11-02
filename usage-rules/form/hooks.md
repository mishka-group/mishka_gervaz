# Form → `hooks`

Server-side lifecycle callbacks, plus a nested `js` block of client-side commands.

```elixir
hooks do
  on_init          fn form, state -> form end
  on_validate      fn params, state -> params end
  on_change        fn field, value, state -> state end       # {:halt, state} stops it
  before_save      fn params, state -> params end            # {:halt, reason} CANCELS the save
  after_save       fn result, state -> state end
  on_error         fn form, state -> state end
  on_cancel        fn state -> state end
  transform_params fn params -> params end
  transform_errors fn changeset, errors -> errors end

  js do
    on_init    fn -> JS.focus(to: "#title") end
    after_save fn record_id -> JS.exec("data-hide", to: "#post-form-modal") end
    on_cancel  fn record_id -> JS.exec("data-hide", to: "#post-form-modal") end
    on_error   fn record_id -> JS.dispatch("shake", to: "#post-form") end
  end
end
```

## Server hooks

| Hook | Arity | Returns |
|---|---|---|
| `on_init` | `form, state` | `form` — after initialization |
| `on_validate` | `params, state` | `params` — on the `phx-change` event |
| `on_change` | `field, value, state` | `state` or `{:halt, state}` — one field changed |
| `before_save` | `params, state` | `params` or `{:cont, params}` to save them, `{:halt, reason}` to cancel |
| `after_save` | `result, state` | `state` — side effects |
| `on_error` | `form, state` | `state` |
| `on_cancel` | `state` | `state` |
| `transform_params` | `params` | ⚠ compiled but not read — see below |
| `transform_errors` | `changeset, errors` | ⚠ compiled but not read — see below |

### ⚠ `transform_params` and `transform_errors` are not wired

Both land in `Info.Form.hooks/1`, but nothing in `lib/mishka_gervaz/form/web/` reads them. The
`transform_params/2` that *does* run is an **overridable callback** on
`MishkaGervaz.Form.Web.Events.SubmitHandler`, which is a different thing:

```elixir
defmodule MyApp.Form.SubmitHandler do
  use MishkaGervaz.Form.Web.Events.SubmitHandler

  def transform_params(state, params) do
    params |> super(state) |> Map.put("ingested_at", DateTime.utc_now())
  end
end
```

```elixir
form do
  events do submit MyApp.Form.SubmitHandler end
end
```

For the simple case use `before_save` instead — it runs, and it can also refuse.

`before_save` receives the save event's params, with the form's values under `"form"`, and the
params it returns, bare or as `{:cont, params}`, are the ones saved. Anything else saves the params
unchanged.

`before_save` is where a refusal belongs. Return `{:halt, reason}`, telling the author yourself,
rather than letting a doomed record reach the action:

```elixir
before_save fn params, state ->
  case refuse(params) do
    nil     -> {:cont, apply_visibility(params, state)}
    message -> {:halt, tell_author(message)}
  end
end
```

## JS hooks

Each returns a `%Phoenix.LiveView.JS{}`. The library pushes it to the browser as a
`"gervaz:exec-js"` event targeting `<component-id>-form-wrapper`, so a modal can close itself
after a save without a round trip through the parent.

| Hook | Arity | Receives |
|---|---|---|
| `on_init` | 0 | — (runs as `phx-mounted` on the form container) |
| `after_save` | 1 | the saved record's id |
| `on_cancel` | 1 | the record id, or `nil` in create mode |
| `on_error` | 1 | the record id, or `nil` in create mode |

Your app needs a client-side listener for `gervaz:exec-js`, or the parent can drive modals from
the `{:form_saved, …}` / `{:form_cancelled, …}` messages instead
([../mounting.md](../mounting.md)). Pick **one** of the two — doing both closes the modal twice.

## TODO
- [ ] `before_save` returns `params` / `{:cont, params}` / `{:halt, reason}` and nothing else
- [ ] `after_save` used for side effects only — it cannot change the result
- [ ] Modal open/close driven by `js` hooks **or** the parent's messages, not both
- [ ] `on_change` returns `{:halt, state}` only where a change must genuinely be swallowed
- [ ] Slow work moved out of `on_validate` — it runs on every keystroke past the debounce
- [ ] `transform_errors` used for wording, not to hide real validation failures

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.hooks`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-hooks) · [`mishka_gervaz.form.hooks.js`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-hooks-js)

**Schema:** `MishkaGervaz.Form.Dsl.Hooks` ·
**Runtime:** `Form.Web.Events.HookRunner`, `Form.Web.DataLoader.HookRunner`
