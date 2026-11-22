# Custom UI adapters

A **UI adapter** answers *how things look*: the button, the select, the badge, the cell. It is one
module implementing `MishkaGervaz.Behaviours.UIAdapter` — 73 one-arity component functions, all
supplied with defaults, so you override only what differs.

Wire it in either DSL:

```elixir
presentation do
  ui_adapter MyAppWeb.UIAdapters.Admin
  ui_adapter_opts component_module: MyAppWeb.Components
end
```

Set it once on the **domain** and every resource inherits it.

## Inheritance and fallback — the whole model

`use MishkaGervaz.Behaviours.UIAdapter` generates a `defdelegate` for **every** component function
to a fallback module, then marks them all `defoverridable`. So:

- an adapter that defines nothing behaves exactly like its fallback;
- an adapter that defines `button/1` changes buttons and nothing else;
- fallbacks chain — your adapter may fall back to another adapter, which falls back to Tailwind.

```elixir
defmodule MyAppWeb.UIAdapters.Admin do
  use MishkaGervaz.Behaviours.UIAdapter          # fallback: MishkaGervaz.UIAdapters.Tailwind

  def button(assigns), do: MyAppWeb.Components.Button.button(assigns)
end
```

### The worked example that ships with the library

`MishkaGervaz.UIAdapters.MediaGallery` is the smallest useful adapter — it changes exactly one
component and inherits the other 72:

```elixir
defmodule MishkaGervaz.UIAdapters.MediaGallery do
  use MishkaGervaz.Behaviours.UIAdapter,
    fallback: MishkaGervaz.UIAdapters.Tailwind

  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :icon, :string, default: nil
  attr :variant, :atom, default: :default
  attr :rest, :global,
    include: ~w(phx-click phx-target phx-value-id phx-value-event phx-value-values data-confirm)

  def button(assigns) do
    assigns =
      assigns
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:variant, fn -> :default end)

    # An action that declares its own `ui do class … end` KEEPS it — that is the escape hatch.
    assigns =
      assign(assigns, :class,
        if(assigns[:class] in [nil, ""], do: default_class(assigns[:variant]), else: assigns.class))

    ~H"""
    <button type="button" class={@class} title={@label} {@rest}>
      <.icon :if={@icon} name={@icon} class="size-[15px]" />
      <span :if={@label not in [nil, ""]} class="lbl">{@label}</span>
    </button>
    """
  end

  defp default_class(:destroy), do: @square <> " border-[#f3ddd9] bg-[#fdf4f3] text-[#c0392b] …"
  defp default_class(_variant), do: @square <> " border-[#ecebe6] bg-white text-[#8a877f] …"
end
```

Three things to copy from it:

1. **Honour a caller-supplied `class`.** The DSL's `ui do class "…" end` must win, or the adapter
   becomes a wall the resource cannot get past.
2. **Always emit the label into the DOM**, even when the design hides it — the paired template
   widens one button and hides the label on the rest. Two shapes here would put the card's layout
   in two places.
3. **Each variant names its own background** rather than tinting a shared one. Two background
   utilities on one element are settled by stylesheet order, not class-string order.

## Generating overrides from a components module

Instead of writing a delegate per component, point the macro at your components module. Each
function is wired only when the target module is **loaded and exports** the matching 1-arity
function; everything else stays on the fallback.

```elixir
# Flat — MyAppWeb.Components.button/1
use MishkaGervaz.Behaviours.UIAdapter, components: MyAppWeb.Components

# Nested — MyAppWeb.Components.Button.button/1
use MishkaGervaz.Behaviours.UIAdapter, components: MyAppWeb.Components, nested_components: true

# Module prefix — MyAppWeb.Components.MishkaButton.button/1
use MishkaGervaz.Behaviours.UIAdapter,
  components: MyAppWeb.Components, nested_components: true, module_prefix: "Mishka"

# Function prefix — MyAppWeb.Components.mc_button/1
use MishkaGervaz.Behaviours.UIAdapter, components: MyAppWeb.Components, component_prefix: "mc_"

# Custom fallback instead of Tailwind
use MishkaGervaz.Behaviours.UIAdapter,
  fallback: MyAppWeb.Components.Base, components: MyAppWeb.Components.Custom
```

| `use` option | Type | Default | Effect |
|---|---|---|---|
| `:fallback` | module | `MishkaGervaz.UIAdapters.Tailwind` | where undefined components go |
| `:components` | module | — | source of auto-generated overrides |
| `:nested_components` | bool | `false` | look under `Components.Button.button/1` |
| `:module_prefix` | string | — | prepended to the submodule name |
| `:component_prefix` | string | — | prepended to the function name |

## The dynamic adapter — components resolved at runtime

`MishkaGervaz.UIAdapters.Dynamic` renders components looked up at runtime (from a database, a
compiled registry, anywhere) and falls back per component when the target is unavailable.

```elixir
presentation do
  ui_adapter MishkaGervaz.UIAdapters.Dynamic
  ui_adapter_opts [
    site: "Global",
    component_renderer: &MyApp.LiveViewHelpers.component/1,
    module_resolver: &MyApp.Compilers.Helpers.module_name/3,
    fallback: MishkaGervaz.UIAdapters.Tailwind
  ]
end
```

| `ui_adapter_opts` key | Shape | Default |
|---|---|---|
| `:site` | any | `"Global"` |
| `:component_renderer` | `(assigns) -> rendered` | — |
| `:module_resolver` | `(component_name, site, kind) -> module` | — |
| `:fallback` | adapter module | `MishkaGervaz.UIAdapters.Tailwind` |

Or bake the options in with `use MishkaGervaz.UIAdapters.Dynamic, site: …, fallback: …`.

## The three ways to build an adapter — compared

| Approach | Write | Best for |
|---|---|---|
| `use …UIAdapter` + hand-written functions | one function per difference | a handful of components differ (see `UIAdapters.MediaGallery`) |
| `use …UIAdapter, components: MyComponents` | nothing per component | you already have a components module with matching names |
| `use …UIAdapters.Dynamic` | a resolver + renderer | components live in a database or are compiled at runtime |

All three end up behind the same `ui_adapter` DSL option, and all three fall back per component.

## The component list

77 callbacks, grouped by what they render. Introspect the live list with
`MishkaGervaz.Behaviours.UIAdapter.component_functions/0`.

- **Inputs** — `text_input` `select` `multi_select` `search_select` `load_more_select` `checkbox`
  `date_input` `datetime_input` `number_input` `textarea` `json_editor` `toggle_input`
  `range_input` `string_list_input` `password_input` `combobox` `choice_cards` `segmented_control`
- **Actions & display** — `button` `icon` `badge` `copy_button` `spinner` `nav_link` `dropdown`
- **State & status** — `empty_state` `error_state` `loading_state` `skeleton` `alert` `toast`
- **Panels** — `drawer` `sheet` `window` `question`
- **Table** — `table` `table_header` `th` `tr` `td` `date_range_container` `cell_empty`
  `cell_text` `cell_number` `cell_date` `cell_datetime` `cell_code` `cell_array` `cell_tags`
  `cell_avatars` `cell_stacked` `cell_stats` `cell_bars` `filter_reset_button` `archive_toggle`
  `bulk_action_bar` `bulk_action_button` `pagination_container` `pagination_nav_button`
  `pagination_page_button` `template_switcher` `template_switcher_button`
- **Form** — `form_container` `form_header` `form_footer` `field_wrapper` `field_group`
  `field_error` `step_indicator` `step_navigation` `upload_dropzone` `upload_preview`
  `upload_progress` `upload_file_input` `upload_existing_file` `nested_fields` `array_fields`

One adapter serves **both** the table and the form — there is no separate form adapter.

## Drawer and bottom sheet

`drawer/1` is a panel from the right side (the left in a right-to-left page) that is a bottom
sheet below 640px; `sheet/1` is a bottom sheet at every width. Both hold a form or any page
content, are drawn hidden and open with `Phoenix.LiveView.JS` — no hook. Draw one with `show` under
an `:if`, or keep it and run the Tailwind adapter's `show_drawer/2` / `show_sheet/2`:

```heex
<MishkaGervaz.Helpers.dynamic_component
  :if={@editing?}
  module={MishkaGervaz.UIAdapters.Tailwind}
  function={:drawer}
  id="product-drawer"
  show
  title={dgettext("mishka_gervaz", "Edit product")}
  on_close={JS.push("close_editor")}
  confirm_close={@product_form_dirty? && dgettext("mishka_gervaz", "Discard your changes?")}
>
  <.live_component module={MishkaGervaz.Form.Web.Live} id="product-form" … notify_dirty />
  <:footer>…</:footer>
</MishkaGervaz.Helpers.dynamic_component>
```

The close button and the backdrop run `on_close` and the close; with `confirm_close` they ask it
first (`data-confirm`), and Escape closes only a panel without one. Keep `confirm_close` from the
form's `{:form_dirty, id, dirty?}` ([../mounting.md](../mounting.md)). `:class` replaces the
panel's width classes.

### The head and the actions row

The head can say what the panel is about: an icon in a tile (`icon`, coloured by `tone`: `:info`,
`:ok`, `:warn`, `:danger`, `:mute`), the `title`, a `sub` line under it, which also describes the
dialog, and `chips` under that, each a label or a `{tone, label}` pair. The `:actions` slot holds
its buttons, in the foot (`actions_at: :foot`, the default) or in the head beside the close button
(`actions_at: :head`); below 640px the foot's buttons are 48px tall and share the row.

```heex
<MishkaGervaz.Helpers.dynamic_component
  module={MishkaGervaz.UIAdapters.Tailwind}
  function={:drawer}
  id="order-drawer"
  show
  icon="hero-receipt-percent"
  tone={:info}
  title={@order.number}
  sub={@order.customer_name}
  chips={[{:ok, "Paid"}, "Card"]}
  on_close={JS.push("close_order")}
>
  <MyAppWeb.OrderViews.order order={@order} />
  <:actions>
    <button phx-click="refund" phx-value-id={@order.id}>Refund</button>
  </:actions>
</MishkaGervaz.Helpers.dynamic_component>
```

A table opens a row in this drawer with a `:drawer` row action
([../table/row-actions.md](../table/row-actions.md)).

## Window

`window/1` is a window in the middle of the screen, for a form or a short page, that is a bottom
sheet below 640px. It takes the drawer's assigns and opens and closes the same way, through
`show_window/2` and `hide_window/2`: it grows in from a little smaller on a desktop and rises from
the bottom on a phone. Its head and its foot stay while its body scrolls. `:class` replaces its
width (`sm:w-[min(560px,calc(100vw-48px))]`).

```heex
<MishkaGervaz.Helpers.dynamic_component
  :if={@noting?}
  module={MishkaGervaz.UIAdapters.Tailwind}
  function={:window}
  id="order-note"
  show
  icon="hero-pencil-square"
  title={dgettext("mishka_gervaz", "Note on the order")}
  on_close={JS.push("close_note")}
>
  <form id="order-note-form" phx-submit="save_note">…</form>
  <:footer>
    <button type="submit" form="order-note-form">Save</button>
  </:footer>
</MishkaGervaz.Helpers.dynamic_component>
```

A window without a `title`, `icon`, `sub` or `chips` draws no head and puts its close button in the
top corner, for a body that draws its own head (a gervaz form with a `header`). A window that stays
rendered and holds a form whose page decides whether it may close takes `request_close`: the close
button, the backdrop and Escape run it instead of closing, the page asks "Discard your changes?"
when it must, and closes the window with `hide_window/2`, pushed to the
client. Every panel keeps the focus inside it (`Phoenix.Component.focus_wrap/1`), puts it on its
first field as it opens and gives it back as it closes; its close button is `<id>-close` and its
body `<id>-body`.

## Question window

`question/1` is the confirm dialog a `confirm` keyword list asks (`MishkaGervaz.Question`): an alert
dialog in the middle of the screen, a bottom sheet below 640px, with `title`, `body`, a `tone`
(`:danger`, `:warn`, `:info`) that colours its button, and its `confirm_label` and
`cancel_label`. It is a form: its button submits `on_confirm`, so Enter answers too, and Cancel,
the backdrop and Escape send `on_cancel`. With an `answer`, a field named `answer` asks for it,
each change sends `on_change`, and the button stays off until what was typed is the answer; an
`error` is said under the field. The server draws it and takes it away: tables and forms draw it
for their own questions, and a page draws one for its own with `MishkaGervaz.Question.window/1`.

## Skeleton

`skeleton/1` stands where content goes while it loads and holds its room: `type: :rows` (the
default), `rows` placeholder rows the height of a table row (`row_class` for taller ones), or
`type: :block`, a box of `lines` with its height in `class`. It is marked `aria-busy` and a screen
reader hears its `text`. The table template draws it while it reads with no rows to show
([../table/states.md](../table/states.md)); a page draws it for a block it reads with
`assign_async`, as many rows as the block showed before, so a reload does not collapse it:

```heex
<.async_result :let={orders} assign={@latest_orders}>
  <:loading>
    <MishkaGervaz.UIAdapters.Tailwind.skeleton rows={@latest_shown || 5} />
  </:loading>
  <.order_row :for={order <- orders} order={order} />
</.async_result>

<MishkaGervaz.UIAdapters.Tailwind.skeleton type={:block} lines={4} class="h-[180px]" />
```

## Toast

`toast/1` is one toast of a page's `MishkaGervaz.Toast.toasts/1` ([../mounting.md](../mounting.md)):
a short dark note with a dot in its `tone`'s colour (`:ok`, `:info`, `:warn`, `:error`), its `text`,
an Undo button when it has an `undo_label`, a link (`navigate`, or `href`, with `link_label`) and a
Close. Its buttons send `gervaz_toast_undo` and `gervaz_toast_close` with `phx-value-id` set to its
`toast_id`; the page's `Toast.attach/1` hook answers them. An adapter that draws its own keeps those
two events and that value.

## TODO
- [ ] `use MishkaGervaz.Behaviours.UIAdapter` rather than `@behaviour` + 73 stubs
- [ ] Only the components that genuinely differ are defined
- [ ] A caller-supplied `class` wins over the adapter's default
- [ ] `attr`/`:rest` declared so `phx-*` and `data-confirm` reach the DOM
- [ ] The label reaches the DOM even when the design hides it
- [ ] `fallback:` set when extending another adapter rather than Tailwind
- [ ] Adapter set on the **domain**, overridden per resource only where it differs
- [ ] Added components verified against `component_functions/0`, not guessed

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Behaviour:** `MishkaGervaz.Behaviours.UIAdapter` ·
**Built in:** `UIAdapters.Tailwind` (default) · `UIAdapters.MediaGallery` · `UIAdapters.Dynamic`
