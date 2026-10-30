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
