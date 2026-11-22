# Changelog for MishkaGervaz 0.0.12

### Features:
- `field :kind, :choice_cards` and `field :billing, :segmented` hold one of a few values, drawn as a
  radio per option: a card each, or a segment each of one bar. An option may be a keyword list or
  map with `:description`, a second line under its label, `:icon`, and `disabled: true` for an
  option that is seen but cannot be picked. The UI adapter gains `choice_cards/1` and
  `segmented_control/1`
- `ui do prefix "USD" end` and `ui do suffix "%" end` put a unit at the start or end of a `:text`,
  `:password` or `:number` input, joined to it and named by `aria-describedby`; it is not saved
- `ui do note "…" end` on a `:toggle` or `:checkbox` field draws the text beside the control, inside
  its label; `description` stays the help text under any field
- A `:multi_select` option may carry a `:description`, drawn under its label; the field still saves
  the ticked values as a list, an empty list when none is ticked
- A `:tabs` form draws its steps as a tablist over their panels. With `navigation :free` any tab
  opens and Save stands on every tab: a save runs `before_save` and the action, and one that fails
  on another tab's field moves there, marks the tab and flashes its name. With `:sequential` only
  visited tabs open and the submit row is a wizard's
- `submit do discard label: "Discard" end` draws a button beside Save while the form holds changes,
  putting the form back to its starting values (`MishkaGervaz.Form.Web.Live.discard/1`); a tabs form
  stays on its tab
- A form mounted with `notify_dirty={true}` sends its page `{:form_dirty, id, dirty?}` when it comes
  to hold changes and when it holds none; its wrapper carries `data-dirty`. A submit button takes
  `confirm`, asked through `data-confirm`, on `cancel` and `discard` only while the form holds changes
- A `:number` or `:range` field takes a `Decimal` or a float `min` and `max`, compared as `Decimal`s
  and drawn on the input as plain digits
- `row do path fn record -> … end end` makes a whole table row open a path: a link over the row,
  reached with Tab, the checkbox, caret and actions above it
- A `:table_footer` slot on the table, drawn under the rows, receives `%{shown: n, total: n}` and
  carries the page's own text and buttons (`Shared.table_counts/1`)
- A row that arrives by a stream insert after the table loaded, over realtime or from a row
  action, fades from a highlight in a few seconds through CSS `@starting-style`;
  `template_options highlight_arrivals: false` turns it off
- `template_options switcher: false` keeps a table's `switchable_templates` and draws no switcher
  (`Shared.show_switcher?/1`)
- The UI adapter gains `drawer/1`, a right-side panel that is a bottom sheet below 640px, and
  `sheet/1`, a bottom sheet, for a form or a page. They open and close with `Phoenix.LiveView.JS`
  (`show_drawer/2`, `hide_drawer/2`, `show_sheet/2`, `hide_sheet/2`) and ask `confirm_close` before
  they close. Their head takes an `icon` in a tile coloured by `tone`, a `sub` line and `chips`
  under the title, and an `:actions` slot of buttons in the foot or, with `actions_at: :head`, in
  the head
- `field :iban, :text do live_errors true end` shows that field's own errors as it is typed, once it
  holds a value, in a form for a new record, which otherwise shows errors only after its first save
- The UI adapter gains `window/1`, a window in the middle of the screen that is a bottom sheet below
  640px, for a form or a short page. It takes the drawer's assigns and opens and closes through
  `show_window/2` and `hide_window/2`; without a title it draws no head and its close button stands
  in the corner. Every panel (drawer, sheet, window) keeps the focus inside it, its close button is
  `<id>-close` and 44px tall on a phone, and `request_close` runs in place of the close, for a page
  that decides on the server whether a panel may close
- A row action `type: :drawer` opens the row in the table's drawer: a record view
  (`open: fn record -> ~H"…" end`) or the resource's form editing it (`open: :form`), its head
  built from the row (`drawer: [title:, sub:, icon:, tone:, chips:, actions:, kind: :sheet]`).
  `MishkaGervaz.Table.Web.Live.close_drawer/2` closes it after a save and puts the saved row back
  in its place; a custom template draws it with `Shared.render_overlays/1`
- A `confirm` given as a keyword list (`title`, `body`, `tone: :danger | :warn | :info`, `answer`,
  `answer_label`, `confirm_label`, `cancel_label`) asks in the UI adapter's new `question/1` window
  instead of the browser's dialog, on a row action, a bulk action (`{count}` in its strings) and a
  form's `create` or `update` button. The server draws it: the action runs, or the form saves what
  was submitted, once it is answered, and with `answer` only once that word is typed
  (`MishkaGervaz.Question`, `Question.bind/4` for a custom action type)
- Toasts: the UI adapter gains `toast/1`, a short note in a tone (`:ok`, `:info`, `:warn`,
  `:error`) with an optional Undo and link, and `MishkaGervaz.Toast` keeps a page's toasts:
  `attach/1` in `mount/3`, `push/4` (`undo:`, `navigate:` or `href:`, `ms:`), `send_toast/3` from a
  component and `toasts/1` to draw them. Each leaves by itself through a timer message in the page's
  own process, no JavaScript, and an Undo sends the page `{:toast_undo, undo}`
- A column `ui do type :site end` names the site of each row of a multi-tenant table, and is drawn
  only while the table reads across tenants, as a master's read of every site does
  (`Shared.across_tenants?/1`, `DataLoader.read_tenant/1`)
- `pagination do ui do load_more_at :footer end end` draws a `:load_more` table's Load more at the
  end of its footer row, beside the `table_footer` slot, instead of in the pager. The slot's counts
  gain `more?` and `loading?`, `Shared.render_load_more/1` draws the button in a custom template and
  `MishkaGervaz.Table.Web.Live.load_more/2` is the JS of a page's own button; each press streams the
  next page, read by keyset when the read action allows it
- The UI adapter gains `skeleton/1`, placeholder rows or a block that hold the room of what loads.
  The default table template draws its frame with placeholder rows before its first read, and in
  place of its empty state while a read with no rows shown runs, as after a filter that found
  nothing, so the table keeps its height; `template_options skeleton_rows: n` sets how many
  (`Shared.skeleton_rows/2`, `Shared.reading_with_no_rows?/1`)
- A `:standard` form mounted with a `:body` slot lets the page place its groups in its own cards or
  steps: `<:body :let={form}>` with `<MishkaGervaz.Form.Web.Live.group form={form} name={:keys} />`
  wherever a group goes, the page's own markup between them. It stays one form, one changeset and
  one save; a field's error shows in its group's card, and the unsaved changes and Discard work as
  before. The slot is drawn while the form loads, each group showing that it loads
- A `:text`, `:textarea`, `:email`, `:password`, `:url` or `:tel` field draws its attribute's
  `max_length` constraint as the input's `maxlength`; `field ... do max_length 80 end` sets its own
- A page puts a value it worked out into a mounted form without starting it over:
  `MishkaGervaz.Form.Web.Live.put_values("plan-form", %{proration_date: date})`, which is
  `send_update/2` with `put_values:`. The form is validated with it as a typed change is and the save
  sends it, a `:hidden` field's included; what the reader typed stays, and the dirty state and the
  step are untouched. A form still reading its record takes the values once it has read it

### Bug fixes:
- A form field with `ui do span 2 end` (3, 4) is the whole row below the breakpoint where the grid
  has that many columns (`col-span-full md:col-span-2`), so on a phone it no longer makes a second,
  implicit column that squeezed every other field
- A `:hidden` form field is drawn as a bare `<input type="hidden">` carrying its value, with no
  label and no text box; before it was a labelled text box a reader could see and type into

### Dependencies:
- phoenix_live_view 1.2.13 => 1.2.14 (EEF-CVE-2026-126334)
- phoenix 1.8.16 => 1.8.17
- ex_doc 0.40.4 => 0.40.5
- rewrite 1.3.0 => 1.3.1

# Changelog for MishkaGervaz 0.0.11

### Features:
- Named table views: `view :name do ... end` inside `table` has its own columns, sort and base filter, and is mounted with `view={:name}`

### Bug fixes:
- A link action named `:edit` or `:show` with no `path` builds its address from the table's route; a `path` still wins
- A `before_save` halt reason shows on the form above the submit row
- A `:number` field draws and saves a `Decimal`
- A `:multi_select` field submits the ticked options as a list
- A text field the author empties saves empty instead of its default
- A URL the table follows drops a search or filter it no longer carries, in the table state and in `UrlSync.apply_url_state/2`
- A search in the URL is read back into the table's own search filter, `:q` or `:search`

# Changelog for MishkaGervaz 0.0.10

### Features:
- A `:date` or `:datetime` field takes `min` and `max`: a `Date`, `DateTime`, `NaiveDateTime`, or
  a function read each time it is drawn or checked, so `min fn -> DateTime.utc_now() end` is always
  now. The calendar greys out the days outside them, a pick outside them moves to the nearest one
  allowed, the browser's own input carries `min` and `max`, and validate and save refuse a value
  outside them with the field's error
- `min` and `max` also take `fn state -> value end`, given the form state as `visible` is (`mode`,
  `current_user`, `master_user?`, `form`, `field_values`), and read the same for the picker and the
  save; `nil` is no bound. `fn %{mode: :create} -> DateTime.utc_now(); _state -> nil end` bounds a
  new record and leaves an edited one free. Number and range fields take the same functions
- A `:datetime` field's `ui` `step` is the minutes between the times its picker offers
- `ui` `first_day_of_week` is the day a `:date` or `:datetime` calendar's weeks start on (Monday
  when not set)

### Bug fixes:
- A date picker keeps its pick when a form change posted before the pick was drawn arrives after
  it; that change carried the old, empty value and emptied the field
- A `:range` field's slider runs from the field's `min` to its `max` (0 to 100 when not set) in its
  `ui` `step`; it read `min` and `max` from `ui`, which has neither, so it always ran 0 to 100. A
  `:number` input carries the same `min`, `max` and `step`, and both refuse a value outside them
  with "is too small" or "is too large"
- A relation select's open list, as wide as its input, wraps a long name at its spaces, breaking a
  word only when one alone is wider, instead of scrolling sideways and cutting it
- A search select or multi-select opens on a click in its input, or Tab into it, through the
  `.SearchSelect` hook; its `phx-focus` waited out the input's debounce, so a click from one open
  list to another select closed the first and left the second shut
- Escape closes an open relation select's list and leaves it closed: the `.SearchSelect` hook
  keeps the keyup of a key that types nothing (Escape, Enter, Tab, an arrow) from the input's
  search, and a table's relation filter searches nothing for one, so the Escape's keyup no longer
  searched and opened the list again
- An Escape pressed right after a relation select was opened or typed in closes its list: the
  hook sends the search still waiting out the debounce before the close, and closes a list whose
  opening is still on its way, so neither reopened it
- Escape in an open combobox or form calendar closes just its list, leaving a modal around the
  form open, and Tab out of one closes it, as it does a relation select's list now: they carry
  the `.SearchSelect` hook, which finds an open list by its `data-role="gervaz-relation-list"`
- A relation select's open list closes on any click outside it again: every search, multi and
  load-more select carries `phx-click-away`, open or shut, whose handler does nothing for a shut
  list. The load-more select carries the `.SearchSelect` hook too, for Escape
- A table's relation filter is drawn whole each time it changes, so an open select's
  `aria-expanded` and debounce are the open ones; it was built with `__changed__: %{}`
- A table's date range filter with only From or only To set filters from or up to that day,
  from the filter bar and from the URL; it needed both and did nothing with one
- A date range filter's From input stops at the To day and the To input starts at the From day,
  and a From after the To is taken the other way round instead of filtering out every row
- A date range filter's inputs are drawn again each time the filter changes on a live page, so a
  typed From sets the To input's `min` (and a To the From's `max`) and a reversed range shows
  swapped at once; they were drawn with `__changed__: %{}`, which a live diff read as unchanged, so
  only a reload showed them. Each input's id names the other side's day, so the input a swap
  changed is drawn anew and shows the swapped day even while it has focus

### Dependencies:
- dialyxir 1.4.8 => 1.4.9

# Changelog for MishkaGervaz 0.0.9

### Bug fixes:
- With select all, the bulk bar names the rows a bulk action reaches ("All 99 selected", or
  "96 selected" once rows are unchecked) when the table knows its total, and keeps "All selected"
  when it does not
- The search select (a relation picker in a form or a table filter) works from the keyboard:
  ArrowDown and ArrowUp move a highlight through the list, Enter picks the highlighted option (or
  the first not already picked) instead of submitting the form, and the input names the highlight in
  `aria-activedescendant`. It runs in a colocated hook, so the host adds gervaz's hooks from
  `phoenix-colocated/mishka_gervaz` to its `LiveSocket` (see the README)
- Escape in an open search select closes only its list, so a modal holding the form stays open;
  the next Escape closes the modal

# Changelog for MishkaGervaz 0.0.8

### Bug fixes:
- The table state's `records_result` and the accordion row results are specced as
  `%Phoenix.LiveView.AsyncResult{}`, since Phoenix LiveView defines no `AsyncResult.t/0` type and
  dialyzer reported it as unknown
- The data loader specs its rows as `Ash.Resource.Record.t()`, since `Ash.Resource.record/0` is not
  defined on OTP 29

### Dependencies:
- ash 3.37.2 => 3.37.4, spark 2.7.9 => 2.7.10, websock_adapter 0.7.0 => 0.7.2

# Changelog for MishkaGervaz 0.0.7

### Bug fixes:
- Picking a related record runs the form's `on_validate` hook like a typed change, so dependent
  fields refresh, and builds its errors with the form's validation handler

# Changelog for MishkaGervaz 0.0.6

### Features:
- A submit button's `loading_label` is what it reads while its save runs
- A `:select` field takes `fn state -> options end`, drawn with the form state

### Bug fixes:
- A group declared collapsed starts closed, and opens when a field inside it has an error
- The wizard's Next and Back move the form's own steps, one step at a time
- A key map stacks its keys on a phone, and the submit row and the steps wrap
- A search picker drops text that was typed and not picked once its list closes
- A search picker narrows its list from the form's change, whether the text is typed, pasted or
  filled in
- A field that holds one value draws empty when its params carry a map or a list
- Gettext template references carry line numbers

# Changelog for MishkaGervaz 0.0.5

### Features:
- Load more reads after the last row shown when the read action has `keyset?: true`. The table keeps
  the keyset of that row (`state.after_keyset`), so a row removed or added elsewhere in the list
  moves no row past it and every click adds a full page. A table without keyset keeps the offset
  (`state.next_offset`), which skips no row after removals; so does a keyset Ash refuses
- A table opened at page N, by `?<prefix>_page=4` after a reload or a shared link, shows a
  "Load earlier" button above its rows. Each click reads the page before the first row shown and
  puts it above, until page 1. Load more still continues after the last row. A template that draws
  its own Load more pager uses `Shared.render_load_earlier/1`, or `phx-click="load_earlier"` while
  `state.first_page > 1`
- Every pager is one row, `Shared.render_pagination_row/1`: the page size selector on the left, Load
  More or the pages in the centre, and on the right "Showing a–b of N" for a Load more or infinite
  table (`Shared.range_label/1`) or the page info on a numbered one. Below 640px the parts stack,
  centred, so a numbered pager no longer runs off a phone
- The accordion row action respects `visible`. The caret and the expanded details show only on rows
  whose accordion is visible and not `restricted`, and the caret column goes when no row can expand

### Bug fixes:
- A page past the last, such as `?<prefix>_page=999`, says "No rows on this page" with a "Go to
  page 1" button that reads page 1 and clears the URL, where a numbered table showed "Page 999 of
  2" over an empty body and a Load more table showed nothing to click
  (`Renderer.past_last_page?/1`; the Tailwind `empty_state` takes `action_click`)
- The bulk bar counts only the picked rows the table still finds. Pick a row, search it away, pick
  another: it reads "1 selected, 1 hidden by the filters", and a confirm's `{count}` is 1. A hidden
  pick stays picked and counts again once the search shows it. A picked row that realtime moves out
  of the view counts as hidden
- The row-actions menu of the Tailwind adapter is a native popover drawn in the top layer, so the
  table's scrolling frame or a card never clips it. It sits under its trigger, or above it near the
  bottom of the screen, and Tab reaches its items. Escape, a click elsewhere or on an item closes
  it. A heading such as "Danger Zone" shows only above a visible item
- Load more on a table without `keep_loaded_records` skips no row after rows another view removed.
  A row deleted, destroyed or restored in the view itself, or taken out by an `override_row_action`
  that answers `{:ok, :stream_delete, row}`, leaves the offset at once (`Events.drop_shown_row/3`)
  and is not counted a second time when its own realtime removal arrives

### Refactors:
- A load no longer holds the page's rows in the state: `records_result` is `%{page:, empty?:}` or the
  failure, and the rows reach the page through the stream. Code that read
  `records_result.result.data.results` needs another source
- Fewer queries. A realtime row costs one read through the table's own read
  (`DataLoader.rows_in_view/2`) in place of an `exists` and a `get`. A burst of notifications, such
  as a bulk action's, waits for one `realtime_flush` message and is read in one `id in ^ids` read,
  and none while the table reloads afresh. Load more on a `keep_loaded_records` table reads one
  page, and a bulk destroy, archive or restore reads none. A built-in `hooks` rule after a row
  action answers from the total without reloading the page
- `Shared.bulk_selection_count/1` subtracts the rows hidden by the filters.
  `DataLoader.PaginationHandler.build_page_opts/5` takes `from_start?` as its fifth argument;
  a load that starts the list afresh with rows picked adds one read of the picked
  ids

# Changelog for MishkaGervaz 0.0.4

### Features:
- `actions_layout` takes a `width`, a grid track such as `"minmax(96px,max-content)"`, which the
  table template uses as the Actions column's track in place of `max-content`. On a table whose rows
  show different buttons by their state, the columns no longer move when a row's buttons change.
  Without a `width` nothing changes
- A `:key_map` or `:key_list` field takes `options fn state -> keys end`, read with the form state
  when the field is drawn and when its params are parsed, so one create form opened with
  `send_update(..., defaults: %{source: "wordpress"}, reset: true)` draws and saves that source's
  keys. A key with `type: :password` is drawn through the adapter's `password_input` with
  autocomplete off and its value is never written back into the page, and a key with
  `required: true` shows the required mark

### Bug fixes:
- A bulk action's button shows the label, icon and class its `ui` block declares, where every bulk
  action showed the humanized action name, no icon and the adapter's class. A `type :update` bulk
  action runs the Ash action its `action` option names: `action {:master_x, :x}` runs `:master_x`
  for a master and `:x` for anyone else, and a plain atom runs itself, where an Ash error took the
  LiveView down
- A bulk action runs on the table's own read, with its filters, search, `path_params` and `on_load`
  hook, so picking every row reaches only the rows the table shows. `:all`, `{:all_except, ids}` and
  a list of picked ids all stay inside that read, where picking every row on a filtered table or on
  a master's table scoped to one site ran the action on every row of the resource
- A table with `keep_loaded_records true` stays whole. A bulk action, an unarchive that skipped some
  rows and a function handler that returns `:reload` reload every page the table had loaded, not
  just the first. A realtime notification changes `loaded_records` as it changes the stream: a row
  already kept is replaced in its place, a new one goes first, and one destroyed or moved out of
  the view is dropped, so a template drawn from them never shows a stale or deleted row
- A page holds every row it asks for. `load_page/5` reads the rest of a page that came back short
  while the read has more rows, so a page larger than the read action's `max_page_size` is full and
  Load more keeps growing the list past it, where the list stopped growing and the button stayed
- A table opens in the template its URL names. With `:template` in `url_sync` params, a reload, a
  shared link, a patch and the Back button apply one of the table's `switchable_templates`, by
  `name/0` or module, and switching writes the template's `name/0` to the URL. A name the table
  does not offer leaves its template
- A URL sort keeps only the fields the table sorts by, a sortable column's `sort_field` or name and
  the fields of the table's default sort. A sort that keeps none opens the table's own sort, where
  `?bloggers_sort=name:desc` on a resource with no `name` field left the table empty
- A URL page and page size are read as positive whole numbers, and anything else (`0`, `-3`, `two`,
  `1.5`, a list) counts as missing. A page whose offset the database cannot read opens page 1, as a
  URL without a page does, and any page that fits still opens. A `go_to_page` or `change_page_size`
  event with a value that is not a positive whole number no longer crashes the table, and
  `go_to_page` on a table that keeps no count opens page 1 for a page past the offset limit
- A search filter is written to the URL once, as `<prefix>_search`, when `:search` is a URL param,
  and no longer again as a filter
- A failed first load keeps the card with its filters, rail, switcher and the rows' place, and shows
  the table's error state with a Retry that loads the first page again with the same filters and
  sort. The table and media gallery templates call `render_error/1`, which draws the `error_state`
  message through the resource's UI adapter. A load that fails after one has succeeded keeps its
  rows
- A form's `restricted fn state -> boolean end` on a field answers whether it is restricted:
  `true` hides the field and leaves it out of what the form saves, `false` draws and saves it
- A field type's `validate/2` refuses a save as it refuses a value while typing, and a save it
  refuses writes nothing
- A field whose type is a module of its own is drawn by that module's `render/2`
- A create form starts with each field's `default` in its params, so the input shows it and a save
  keeps it, unless the mount's `defaults` give that field a value. The field options `apply`,
  `format`, `render`, `options_source` and `array_fields`, and an `auto_fields` override's `format`,
  which nothing read, leave the DSL
- The `after_save` and `on_error` server hooks run on a save: `after_save` with the saved record,
  and `on_error` with the form a failed save left, the state it returns being the one the form
  shows. `before_save` saves the params it returns as a bare map, as it does `{:cont, params}`. The
  hooks DSL offers only hooks a form runs, so `transform_params` and `transform_errors`, which
  nothing ran, leave it
- A notice at `:before_fields` is drawn before the fields no group holds, and a step offers no
  `visible` option, since no navigation or step bar reads it
- A form with a closed mode needs none of that mode's source actions. With `access :update, false`
  a create-only form with just `create` set compiles without the "Missing required form source
  action(s)" warning, because the required actions are those of the open modes

### Docs:
- The table source usage rules say that the active and archived views each keep their own filters,
  sort and selection, that a URL-synced table writes the URL without the active view's filters and
  sort after the first switch to the archive, and that which view is open is not URL state

# Changelog for MishkaGervaz 0.0.3

### Bug fixes:
- A search select is a combobox over a listbox. Its text input names the listbox it controls, each
  choice is an option with `aria-selected`, a group of options is a group named by its heading, and
  the list is named by the field's label. The options stay buttons, so Tab reaches them and Enter or
  Space picks one, and Escape closes the open list. Screen readers now hear a list of options, which
  one is picked and what the input is for, where the picked one was told apart by its tint alone
- The first click on an option of a search select picks it. The search and multi select kept their
  `phx-debounce` while their list was open, so pressing an option after typing blurred the input,
  LiveView sent the waiting keyup, and the answer redrew the list between the press and the release.
  They now keep the debounce only while the list is shut. With the list open each keyup searches at
  once, and the list on screen is the one the click acts on
- Dependencies and security: `phoenix_html` 4.4.0 replaces 4.3.0, which carried advisory
  EEF-CVE-2026-117645. `ash` 3.37.2 replaces 3.37.0 and fixes EEF-CVE-2026-96581 (an upsert on the
  primary key ignored attribute multitenancy) and EEF-CVE-2026-114214 (a through relationship
  loaded with limit 1 returned unrelated records). `ash_phoenix` 2.3.26, `crux` 0.1.5, `igniter`
  0.8.5, `spark` 2.7.9, `splode` 0.3.3 and `websock_adapter` 0.7.0 follow, so every dependency is
  at its latest release

### Refactors:
- A GitHub Actions workflow runs `mix hex.audit` on pull requests, master and every day and sends
  its report to code scanning, the test workflow runs `mix deps.audit` (`mix_audit` is a dev and
  test dependency), and Dependabot checks the Hex dependencies and the Actions every week. Hex
  dependency graph submission feeds GitHub's dependency graph
- The workflows and `.tool-versions` run on Erlang 29.1.2 and Elixir 1.20.5. The temporary OTP 29.0.5
  pin is removed, because the download libraries now pass `max_header_size` to `:httpc`
- The comments on the search select and the icon input say what each part does

# Changelog for MishkaGervaz 0.0.2

### Bug fixes:
- The Hex package ships `priv`, so `MishkaGervaz.Gettext` has its templates and translations

# Changelog for MishkaGervaz 0.0.1

Initial release.
