# Custom column, filter, action and field types

A **type** is a reusable renderer for one kind of value. Write one when the same `render fn …` is
about to be copied into a second resource; keep it inline until then.

Every registry accepts a module **directly** — no registration step:

```elixir
column :background_color do ui do type MyApp.ColumnTypes.Color end end
filter :category, MyApp.FilterTypes.TreeSelect
action :archive, type: MyApp.ActionTypes.Confirm
field  :background_color, MyApp.FieldTypes.Color
```

## Column type — `MishkaGervaz.Table.Behaviours.ColumnType`

```elixir
defmodule MyApp.ColumnTypes.Color do
  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(value, _column, _record, _ui) do
    assigns = %{value: value}
    ~H"""
    <div class="w-6 h-6 rounded" style={"background: #{@value}"}></div>
    """
  end

  @impl true
  def cell_class(_column), do: "text-center"      # optional
end
```

| Callback | Arity | Receives |
|---|---|---|
| `render/4` | required | `value` (after `format`), the column config map, the full `record`, the UI adapter module |
| `cell_class/1` | optional | the column config map |

The column map carries `ui.extra`, which is how a type takes options:

```elixir
ui do type MyApp.ColumnTypes.Color; extra %{shape: :pill} end
```

Built-ins to read as examples: `Table.Types.Column.{Badge, Bars, Tags, Avatars, Link, Boolean}`.

## Filter type — `MishkaGervaz.Table.Behaviours.FilterType`

Three responsibilities: draw the input, parse the raw params, apply to the query.

```elixir
defmodule MyApp.FilterTypes.DateRange do
  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component
  import Ash.Expr

  @impl true
  def render_input(filter, value, ui) do
    assigns = %{filter: filter, value: value || %{}, ui: ui}
    ~H"""
    <div class="flex gap-2">
      {@ui.date_input(%{name: "#{@filter.name}_from", value: @value[:from]})}
      {@ui.date_input(%{name: "#{@filter.name}_to",   value: @value[:to]})}
    </div>
    """
  end

  @impl true
  def parse_value(%{"from" => from, "to" => to}, _filter),
    do: %{from: Date.from_iso8601!(from), to: Date.from_iso8601!(to)}

  def parse_value(_raw, _filter), do: nil

  @impl true
  def build_query(query, field, %{from: from, to: to}) do
    query
    |> Ash.Query.filter(^ref(field) >= ^from)
    |> Ash.Query.filter(^ref(field) <= ^to)
  end
end
```

| Callback | Arity | Note |
|---|---|---|
| `render_input/3` | required | `filter, value, ui_adapter` |
| `parse_value/2` | required | raw form params → the value your `build_query` expects |
| `build_query/3` | required | `query, field, value` |
| `build_query/4` | optional | `query, field, value, filter` — take this when you need the whole filter config (multi-field search) |
| `label/1` | optional | |

Built-ins: `Table.Types.Filter.{Text, Select, Boolean, Number, Date, DateRange, Relation}`.

## Action type — `MishkaGervaz.Table.Behaviours.ActionType`

```elixir
defmodule MyApp.ActionTypes.Confirm do
  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component
  import MishkaGervaz.Helpers, only: [humanize: 1, dynamic_component: 1]

  @impl true
  def render(assigns, action, record, ui, target) do
    assigns =
      assigns
      |> assign(:module, ui)
      |> assign(:function, :button)
      |> assign(:label, action[:ui][:label] || humanize(action[:name]))
      |> assign(:icon, action[:ui][:icon])
      |> assign(:class, action[:ui][:class])
      |> assign(:record_id, record.id)
      |> assign(:target, target)
      |> assign(:confirm, action[:confirm] || "Are you sure?")

    ~H"""
    <.dynamic_component
      phx-click={@action[:event] || "confirm"}
      phx-value-id={@record_id}
      phx-target={@target}
      data-confirm={@confirm}
      {assigns}
    />
    """
  end
end
```

`render/5` receives `assigns, action, record, ui, target`. `assigns` carries the full table state:
`assigns[:state].master_user?`, `assigns[:state].config[:identity][:route]`, and so on. Render
through the **`ui` adapter** rather than emitting raw markup, or the action stops matching the
design system.

Built-ins: `Table.Types.Action.{Link, Event, Edit, Destroy, Update, Unarchive, PermanentDestroy,
RowClick, Accordion}`.

## Field type — `MishkaGervaz.Form.Behaviours.FieldType`

```elixir
defmodule MyApp.FieldTypes.Color do
  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use Phoenix.Component

  @impl true
  def render(assigns, _config) do
    ~H"""
    <input type="color" name={@name} value={@value} />
    """
  end

  @impl true
  def sanitize(value, _config), do: value          # optional

  @impl true
  def parse_params(value, _config), do: value      # optional

  @impl true
  def validate(value, _config), do: {:ok, value}   # optional

  @impl true
  def default_ui, do: %{type: :color}              # optional
end
```

| Callback | Required | Note |
|---|---|---|
| `render/2` | ✔ | `assigns, config` — the Standard template draws the field with it, inside its label and errors; `assigns` carry `name`, `id`, `value`, `placeholder`, `disabled` and `module` (the UI adapter) |
| `sanitize/2` | — | runs **before** validation; text types strip HTML, textarea/json/nested pass through |
| `parse_params/2` | — | raw param → typed value |
| `validate/2` | — | `{:ok, value}` \| `{:error, message}` |
| `default_ui/0` | — | baseline UI config for the type |

Built-ins: `Form.Types.Field.*` — `Relation` and `Nested` are the substantial ones; `Hidden` is
the smallest.

> Sanitization is a real defence, not decoration: the library strips HTML from text input for you.
> A custom type that skips `sanitize/2` opts out of it.

## The four behaviours — compared

| | Renders | Signature | Also does |
|---|---|---|---|
| `ColumnType` | one table cell | `render(value, column, record, ui)` | optional `cell_class/1` |
| `FilterType` | one filter input | `render_input(filter, value, ui)` | parses params **and** builds the query |
| `ActionType` | one action button | `render(assigns, action, record, ui, target)` | — |
| `FieldType` | one form input | `render(assigns, config)` | sanitize / parse / validate / default UI |

Only `FilterType` touches the query; only `FieldType` touches incoming values.

## Type registries

`MishkaGervaz.Table.Types.{Column, Filter, Action}` and `MishkaGervaz.Form.Types.Field` all use
`MishkaGervaz.Table.Behaviours.TypeRegistry`, which gives each `get/1`, `builtin_types/0`,
`builtin?/1`, `default/0`, `get_or_passthrough/1` and (for columns and fields)
`infer_from_ash_type/1`.

`get_or_passthrough/1` is why a module works without registration — an atom it does not know is
returned **unchanged**. That is also why a typo in `ui do type :imagee end` does not fail at
compile time. Call `MishkaGervaz.Table.Types.Column.builtin?(:image)` when in doubt.

## TODO
- [ ] The rendering genuinely repeats — otherwise keep it in `render fn … end`
- [ ] Callback arities and argument order copied from the table above
- [ ] Rendered through the passed `ui` adapter, not with hard-coded markup
- [ ] Options taken from `ui.extra` / the config map, not from module attributes
- [ ] `FieldType.sanitize/2` implemented for anything accepting free text
- [ ] `FilterType.build_query/3` (or `/4`) covers the `nil` value case
- [ ] Type name checked with `builtin?/1` before assuming a built-in exists

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`

**Behaviours:** `Table.Behaviours.ColumnType`, `.FilterType`, `.ActionType`,
`Form.Behaviours.FieldType`, `Table.Behaviours.TypeRegistry`
