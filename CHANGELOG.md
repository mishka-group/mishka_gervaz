# Changelog for MishkaGervaz 0.0.14

### Features:
- A page chooses the steps of a wizard or tabs form it mounts: `navigation` (`:sequential` or
  `:free`) in place of the resource's, so one resource is drawn as steps in order while a record is
  made and as free tabs once it exists; `step`, the step the form opens on, from a URL say, with the
  steps before it counted as done; and `notify_step={true}`, which sends the page
  `{:form_step, id, step}` each time the form moves to another step
- A wizard step says `save true` to have its Next save what the form holds, a create first and an
  update after: the page is sent `{:form_saved, mode, record}` and the form opens the saved record
  for editing on the next step, so a reader who leaves half way keeps a draft. An update save of a
  form mounted with a `record_id` keeps the step or tab it was made on, where before the form went
  back to its first step
- A page adds its own markup to one step of a wizard or tabs form with an `:in_step` slot naming the
  step: it is drawn in the step's panel after its groups, inside the one form, and given the form
  as the `:body` slot is
- A `:key_list` field names each row by what it holds with `row_label`: a key, `row_label :currency`,
  whose value the row's head reads, so a list of amounts reads "USD" and "EUR" rather than "1" and
  "2", or `fn row -> label end` / `fn row, index -> label end`. A row whose label is empty, a new
  row, reads "New" until its key is chosen, every row without the option reads its number, and the
  label names the row's group for a screen reader. A `:select` key's empty choice reads "Choose"
  when it sets no placeholder or one that names one of its options, so it never looks chosen

### Bug fixes:
- A toast is read once by a screen reader: the toasts' container is the page's one polite live
  region, and a toast inside it no longer carries a `role="status"` of its own
- `MishkaGervaz.Table.Web.Live.reorder/2` draws a row that is still arriving: a page that hands the
  table a new row as a realtime notification and asks for it in order at once sees it where the
  order puts it, also just past the rows shown, where before the row was left out
- A window a page closes when its form is saved fades out over the values that were saved: the
  save's own render keeps them, with no error left on it, and the form starts over in a later
  render, which LiveView holds until the fade ends. Before, the form was emptied in the save's
  render and the window faded out over an empty form
- A drawer, a sheet or a window focuses the first field of its body as it opens, so what the reader
  types goes there at once; a body with no field takes the focus at its own top. Before, the close
  button took the focus, so typing went nowhere. The close button is still reached by Shift+Tab
  and Escape, and closing scrolls the body back to the top, so it opens at the top again and not
  where the reader left it
- A gervaz form with tabs or steps in a drawer, a sheet or a window puts the reader in the first
  field of its current tab or step as the panel opens, and not on its tab or step buttons: the
  current step is marked `data-panel-focus`, and the panel focuses the first field of an element so
  marked in its body
- The field a drawer, a sheet or a window focuses as it opens keeps the focus once the panel's
  transition ends. Before, LiveView's focus wrap moved the focus to the panel itself at that moment,
  since the panel had a `tabindex`, so typing went nowhere
- A gervaz form in a drawer, a sheet or a window that its opener starts over with `reset` keeps the
  reader in its first field: the form drawn anew focuses the field the panel focused as it opened,
  the first field of its current tab or step or its own first one, and an edit takes the focus the
  same way once its record has loaded. Before, the open focused the old form's field, the start
  over drew a new `<form>` in its place and the focus fell to the page, so typing went nowhere
- A form whose page refreshes its `defaults` while it is open keeps what was typed, its errors and
  the tab or step it is on, and its notices and options read the new values. It starts over only
  as a create form with no changes, when a field's own default is among what changed. Before, any
  change to `defaults`, such as a product's name or a count the page passes for a notice, started
  the form over on its first step and threw away what was set on the others
- A form that reads the record it is on again, after an update save, a Discard or a start over,
  keeps drawing its steps, the step it is on and the page's `:in_step` entries until the record
  arrives, and the fresh form takes their place then. A live component in an entry, a table with a
  stream say, keeps its rows. Before, the form drew its loading state in between, so every step
  flickered and a live component in an entry came back empty. A save sent in between does nothing
- Cancel on an edit with no `on_cancel` hook puts back the record's saved values and stays on the
  record, on the step or tab it is on. Before, it threw the record away and returned the form to an
  empty create form
- An uploaded file is copied to a random name in the temp folder, never to one built from the
  client's file name, and the action gets the client's name only as data, the part after its last
  `/` or `\` with control characters taken out. Before, a client name such as `../../etc/passwd`,
  `docs/readme.txt` or `<b>x</b>.txt` went into the temp path, so the copy failed and the save
  crashed the LiveView
- A save that fails keeps the files dropped on the form, so the next save hands them over, and a
  file removed after it is not handed over again. Before, the failed save used the files up: the
  next save handed the action a file that was gone, and removing or dropping it again left the
  form unable to save. A save that goes through no longer crashes the LiveView as the form starts
  over while it lets its files go
- An upload says how many files it takes ("You can add up to 5 files") when more are dropped, and
  names each empty file the browser left out ("This file is empty: notes.txt"), dropped or chosen
  with the file picker; its errors are
  translated. Each file's remove button carries an `aria-label` that names the file. Before, an
  empty file vanished with no word and the remove buttons had no name a screen reader could read
- A wizard or tabs form that moves to another step, by Next, Back, a tab or a `step` the page
  passes, focuses the first field of the step it moved to. Before, the button pressed went away
  with its step and the focus fell to the page
- A `:tabs` form whose steps open in order keeps every tab open on a saved record, however it is
  opened and wherever it moves, and never draws the tab shown as disabled: Back counts the step it
  lands on as visited. Before, opening a saved record on its first step, or a step save that read
  the record again, locked the later tabs, and Back after a jump forward could land on a tab drawn
  shown and disabled at once
- The tab strip of a `:tabs` form scrolls the current tab into view as the form moves, so on a
  phone, where the strip scrolls sideways, the tab shown is never off the edge. It scrolls the
  strip alone, never the page
- A form changed back to where it started holds no changes: a typed change compares what the form
  holds with what it held as the first change arrived, so text typed and put back, or a
  multi-select ticked and unticked again, no longer asks "Discard your changes?" and tells a page
  with `notify_dirty` it holds none. A file waiting on an upload still counts as a change. Values
  compare the way a browser sends them: a required select with no empty choice holds the option it
  shows first, and a field a page gave in `defaults` holds what is typed over it
- A text or number input whose value a save refused keeps what was typed while the error stands
  under it: "1e5" refused stays "1e5" rather than the "100000" it was read as
- The open list of a `:search_multi` relation closes on Escape wherever the focus is, a clicked
  option included, and the focus goes back to its search input

# Changelog for MishkaGervaz 0.0.13

### Features:
- A refused save moves the reader to the first field with an error, in the order the form draws
  them: the field is focused and scrolled into view, and a collapsed group or another step that
  holds it opens first. A refusal no field shows moves the reader to the message above the submit
  row. It runs on `Phoenix.LiveView.JS`, so the page needs no hook
- A form mounted with `notify_failed={true}` sends its page `{:form_failed, id, failure}` each time a
  save is refused, `failure` being `%{mode:, fields:, messages:}`, for a toast of the page's own
- A `:number` or `:range` field that names no `min` or `max` takes the `min` and `max` constraints of
  its attribute, as a text field takes its `max_length`
- A form group draws its `ui` `description` under its label

### Bug fixes:
- An error under a field names the field: "is required" under Name reads "Name is required". A
  message that already ends a sentence is shown as written (`MishkaGervaz.Errors.label_message/2`)
- A number past its `min` or `max` shows one sentence that names the limit, "Seats must be 10 or
  less" or "Price must be 0.50 or more", where before it read "is too large" or "is too small"; the
  action's own sentence for the field still comes first
- A `:text`, `:textarea` or `:password` value past its `max_length` is refused in words, "Name must be
  20 characters or fewer", where it was accepted when it got past the input's `maxlength`
- A `:text`, `:combobox` or `:string_list` value that holds an HTML tag, such as `<b>Ann</b>`, stays
  as typed and is refused with "must be plain text, without HTML tags"; before, the tags were
  removed under the reader and the changed text was saved. A bare `<` or `>` is text and is taken. A
  custom field type refuses a value in `validate/2`, not by rewriting it in `sanitize/2`
- A `:number` field is a text input with the phone's decimal keyboard, so a typed `3-1` reads "must
  be a number"; before, the browser sent it as an empty value and the form said "is required"
- A required field's text, password, number, textarea or select input carries `required`, and every
  form is `novalidate`, so the browser never shows a message of its own or blocks a save: each
  message comes from the form, under its field, in the reader's language
- A form group with neither a label nor a description starts with its fields, with no gap above them
- On a tablet (641px to 980px) a table's rows are cards with their values in two columns, the
  checkbox and the actions on lines of their own, so a card is half as tall; on a phone they stay
  one column
- A toast with the same words as one already shown takes its place, so a button pressed twice shows
  its sentence once, with its time starting again
- On a touch screen a switch, a choice card and a segment of a segmented control are pressed over
  their whole area, at least 44 px tall, and a toast's Undo, link and close are 44 px targets; the
  radio of a choice card is drawn as a dot of its own
- The copy button (`copy_button/1`) keeps its size: while the host's `CopyToClipboard` hook marks
  it `data-copied`, a check icon of the same size takes the copy icon's place and a polite live
  region says "Copied". Before, the hook's "Copied!" text replaced the 12 px icon, so an icon-only
  button grew and its table cell moved. It needs the host hook that sets `data-copied` instead of
  writing into the button

### Dependencies:
- ash 3.37.7 => 3.38.1
- lazy_html 0.1.14 => 0.1.15
- igniter 0.8.5 => 0.8.6

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
- A submit, cancel or discard label, and a field's `description`, may be a function of the form state,
  so one form names its button for the action it was opened for and its help text for what the
  mount's defaults hold
- `submit: :external` on a form's mount hides its submit row for a create and for an edit, for a page
  whose own buttons carry `form=<form id>`; `submit: false` still hides a create's only
- A page puts a value it worked out into a mounted form without starting it over:
  `MishkaGervaz.Form.Web.Live.put_values("plan-form", %{proration_date: date})`, which is
  `send_update/2` with `put_values:`. The form is validated with it as a typed change is and the save
  sends it, a `:hidden` field's included; what the reader typed stays, and the dirty state and the
  step are untouched. A form still reading its record takes the values once it has read it
- A page draws a table's rows in its order again after a row's sort field changed, such as a file
  moved up or down a list ordered by its position: `MishkaGervaz.Table.Web.Live.reorder("files-table",
  moved)`, which is `send_update/2` with `reorder:`. The table reads as many rows as it shows again
  from its first page, in its order, with one more for each moved row
  (`DataLoader.rows_in_window/2`), and draws them afresh in that order, so the rows stand in the
  DOM where they belong with no CSS `order`. A row moved in from a later page stands in its place, a
  row shown that now stands just past them stays below them, and the calls of a burst are read once

### Bug fixes:
- A form field with `ui do span 2 end` (3, 4) is the whole row below the breakpoint where the grid
  has that many columns (`col-span-full md:col-span-2`), so on a phone it no longer makes a second,
  implicit column that squeezed every other field
- A bidirectional table's Previous, Next and page numbers add a history entry when they write the
  URL, so the browser's Back returns to the page before; a filter, a sort or a search still
  replaces the entry there
- A table's footer counts the rows the view shows (`shown_ids` of the table state): a row that
  arrives or moves into the list over realtime counts, and a row Load more reads again counts once;
  before, it counted to the offset Load more reads from
- The `sort` event sorts only by a column declared `sortable`; any other column name changes
  nothing, where before it sorted by it and could fail the read, as a calculation without
  `expression/2` does
- A table reads from the URL only what each parameter may hold (`UrlSync.decode/3`): a text of at most
  `max_filter_length` characters for the sort, search, page, page size and template, and a filter's
  value as its type takes it. A map such as `?sort[a]=b` and anything else reads as missing, and null
  bytes and bytes that are no UTF-8 are cut, where before the page failed. A `:text` or `:select`
  filter keeps a `,` or `~` of its text, and a list among the preserved params is written back
- A table whose read answers with an error shows its error state and logs one warning; before, the
  load crashed. `PaginationHandler.load_page/5` returns `{:error, error}` then
- A `:hidden` form field is drawn as a bare `<input type="hidden">` carrying its value, with no
  label and no text box; before it was a labelled text box a reader could see and type into
- A form in a drawer, sheet or window keeps its tabs or steps at the top of the panel's body and
  its submit row at the bottom while only its fields scroll, so Save is in reach on a short screen
  and after a failed save; each sticks where it rests, so neither slides when the body scrolls. The
  body is marked `data-role="gervaz-panel-body"`. On a phone the form's
  tabs and its submit row's buttons are 44 px tall

### Dependencies:
- phoenix_live_view 1.2.13 => 1.2.15 (EEF-CVE-2026-126334)
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
