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
