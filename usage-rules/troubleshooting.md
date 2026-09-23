# Troubleshooting

Every message below is raised by a `Spark.Dsl.Verifier` at **compile time** and names the DSL path
that failed. Runtime symptoms follow.

## Compile errors — table

| Message | Cause | Fix |
|---|---|---|
| `identity section is required` | any column/filter/row action/bulk action exists without `identity` | add `identity do name :x; route "/admin/x" end` |
| `identity.name is required` / `identity.route is required` | one of the two is missing | both are required once the table has entities |
| `Missing required table source action(s): …` | `read` (always), `get` (interactive rows), `destroy` (a `:destroy` action) | declare them on the resource or the domain — see [table/source.md](table/source.md) |
| `No columns defined for the table.` | a `columns` block with nothing in it | add a `column`, or `auto_columns do … end` |
| `Column \`x\` is not a resource field.` | the name is not an attribute or relationship | add `static true` (and `requires`) — it is computed |
| `Static column \`x\` with render requires \`requires\` option.` | `static true` + `render` without `requires` | list the fields the render reads |
| `Static sortable column \`x\` must specify \`sort_field\`.` | `static true` + `sortable true` | add `sort_field [:db_field]` |
| `Column \`x\` has invalid sort_field values: …` | `sort_field` names a non-existent field | use a real attribute or relationship |
| `Filters depend on non-existent filters: …` | `depends_on` names a missing filter | declare the parent filter |
| `Relation filter :x uses :static mode but the target resource's …` | the target's read action requires pagination | set `required?: false` on it, or use `mode :search` / `:load_more` |
| `Relation filter :x uses a function for display_field but …` | a function `display_field` without `search_field` | add `search_field :name` |
| `Action :x of type :link requires a :path option` | | add `path "/admin/x/{id}"` |
| `Action :x of type :event requires an :event option` | | add `event "my_event"` |
| `Dropdown :x requires a ui block with label` / `requires a label in ui block` | | add `ui do label fn -> … end end` |
| `archive section requires AshArchival.Resource extension` | an `archive` block on a non-archival resource | add the extension, or delete the block |
| `AshArchival.Resource is in the resource extensions, but no archive configuration is defined.` | the reverse | add `archive do … end` on the resource or the domain |
| `realtime prefix is required when enabled.` | `realtime` without `prefix` | add `prefix "posts"`, or `enabled false` |
| `UI adapter module … is not loaded` / `PubSub module … is not loaded` | typo or missing dependency | check the module name |
| pagination errors (`page_size`, `page_size_options`, `type`, `max_page_size`) | see [table/pagination.md](table/pagination.md) | `page_size ∈ options`, `max_page_size ≥ max(options)` |
| `Duplicate notice names: …` / `Notice \`x\`: invalid notice position …` | | copy the position from [table/layout.md](table/layout.md) |

## Compile errors — form

| Message | Cause | Fix |
|---|---|---|
| `form identity.name is required` | | declare `identity do name :x_form end` |
| missing `create` / `update` / `read` | a form with any field lacks one | declare all three on the resource or the domain |
| `Field \`x\` is not a resource attribute.` | the name is not an attribute/relationship/calculation/aggregate | add `virtual true` (+ `resource` for `:relation`/`:select`) |
| `Field \`x\` depends_on \`y\` which is not a defined field.` | | declare `y` in the same form |
| virtual `:relation` / `:select` without `resource` | | add `resource MyApp.Thing` |
| `nested_field` outside a `:nested` field | | move it inside a `field :x, :nested` |
| `Group \`x\` references fields that don't exist: …` | | fix the name, or declare the field |
| `Group \`x\` contains fields already in another group: …` | groups must partition fields | remove the duplicate |
| `Layout mode \`:wizard\` requires at least one step to be defined.` | | add `step :name do groups […] end` |
| `Steps cannot be defined when layout mode is \`:standard\`.` | | switch to `:wizard` / `:tabs`, or delete the steps |
| `Navigation \`:free\` is not valid with \`:wizard\` mode.` | | use `:tabs` for free navigation |
| `Step \`x\` references groups that don't exist: …` / `contains groups already in another step` | | steps must partition groups |
| `At most one step can have \`summary: true\`` | | keep one review step |
| `Upload \`x\` references field \`y\` which doesn't exist.` | | declare `field :y, :upload` |
| `Upload \`x\` has invalid accept format …` | | `"image/*,.pdf"` or `~w(.jpg .png)` |
| `Upload \`x\` references external/writer module … which could not be loaded.` | | check the module name |
| `Duplicate notice names` / invalid position / `only_steps references unknown steps` | | see [form/chrome.md](form/chrome.md) |
| a preload raises about pagination | a preloaded relationship's read action requires pagination | `pagination offset?: true, required?: false` on that action |

## Runtime symptoms

| Symptom | Likely cause |
|---|---|
| `BadArityError` in a predicate | wrong arity — row actions are `fn record, state`, everything else is `fn state`. See [../usage-rules.md](../usage-rules.md) §6 |
| `Ash.Error.Invalid.LimitRequired` | a preloaded relationship's read action requires pagination |
| `"Aggregate queries not supported"` | `pagination ui do show_total true end` on a data layer that cannot count — set it `false` |
| `render` receives a map, not a value (or vice versa) | `static true` + `requires` changes the argument. See [table/columns.md](table/columns.md) |
| a cell renders blank or raises | `ui do type … end` names an atom with no renderer module — see the renderer-backed list in [table/columns.md](table/columns.md) |
| a column shows `%Ash.NotLoaded{}` | the relationship is not in `source.preload` |
| a master sees one relationship, a tenant another | intended — that is `preload master:` / `tenant:` with the alias mapping |
| no rows after adding a route param | a path param whose name matches an attribute became a filter. See [table/identity.md](table/identity.md) |
| a bulk-action flash never appears | `Phoenix.LiveView.put_flash/3` from inside the component — use `BulkActionHooks.put_flash/3` **and** add the `{:put_flash, kind, msg}` bridge |
| the table never auto-refreshes | the parent does not forward `:gervaz_refresh` |
| realtime updates never arrive | the parent does not forward `%Phoenix.Socket.Broadcast{}`, or `realtime.prefix` does not match the resource's `pub_sub` topic |
| URL filters are ignored | `handle_params` does not call `UrlSync.decode/3`, or `url_state` is not passed to the component |
| load-more loses earlier pages in a custom template | the template groups rows and needs `keep_loaded_records true` |
| the form renders no fields | the mode is denied by `source.access`, leaving `loading: :denied` |
| a modal closes twice, or flickers | both the `js` hooks and the parent's `{:form_saved, …}` handler are closing it — pick one |
| a hidden field's value is missing on save | `hidden_fields` without a matching `defaults` entry |
| a JS hook does nothing | the root element lost `id={"#{@static.id}-form-wrapper"}`, or there is no `gervaz:exec-js` listener |
| the DSL reformats with parentheses | `:mishka_gervaz` missing from `import_deps`, or `Spark.Formatter` missing from `plugins` |
| a domain default is ignored | that key is not inheritable — check the table in [../usage-rules.md](../usage-rules.md) §3 |
| `realtime enabled false` seems ignored | it is not — resource `false` beats domain `true`; check you set it on the resource |

## Declared but not wired — the complete list

These options are accepted by the DSL and land in the compiled config, but **no built-in template,
handler or loader reads them**. Setting one changes nothing today; each row names what to use
instead. Verified against `lib/` at v0.0.1-alpha.5.

| Where | Option | Use instead |
|---|---|---|
| table `column` | `searchable` | `filter :search, :text, fields: [...]` |
| table `column` | `filterable` | declare the filter in `filters do … end` |
| table `column` | `export`, `export_as` | nothing — there is no built-in export |
| table `filter` | `presets` | a `:select` filter with explicit `options` |
| table `filter` | `virtual` | advisory only — `resource` + `apply` do the work |
| table `presentation` | the whole `responsive` block | `ui do class "max-md:hidden" end` on the column |
| table `presentation` | `features :export` / `:reorder` / `:inline_edit` | nothing — no template renders them |
| table `row` | `selectable` | it makes `get` required; the checkboxes come from `:select` + bulk actions |
| form `field` | `apply`, `format`, `render`, `options_source`, `array_fields` | `hooks before_save`, a custom field type, or the UI adapter |
| form `step` | `action`, `on_enter`, `before_leave`, `after_leave` | override `StepHandler.can_advance?/2` |
| form `layout` | `responsive` | CSS on the group / field |
| form `presentation` | `features` | remove the DSL that produces the feature |
| form `upload` | `show_preview`, `dropzone_text` | `ui do label … end`, or the adapter's `upload_dropzone/1` |
| form `hooks` | `transform_params`, `transform_errors` | `before_save`, or override `SubmitHandler.transform_params/2` |

Everything else in these rules is wired. `row do class do possible [...] end end` is a deliberate
exception — it exists so Tailwind's scanner sees the literals, and is never read at runtime.

## When the answer is not here

Read the schema module named at the bottom of the relevant section file, or introspect the
compiled result:

```elixir
MishkaGervaz.Resource.Info.Table.config(MyApp.Post)
MishkaGervaz.Resource.Info.Form.config(MyApp.Post)
MishkaGervaz.Domain.Info.Table.config(MyApp.Blog)
```

That map is exactly what the runtime reads — if a value is wrong there, the DSL is the problem;
if it is right there, the template or adapter is.

## DSL reference

The complete, schema-generated option list for every section:

- [`MishkaGervaz.Resource` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html) — the `table` and `form` sections on a resource
- [`MishkaGervaz.Domain` DSL](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html) — the domain-wide defaults and `navigation`
