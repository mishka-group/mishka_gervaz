# MishkaGervaz `__using__` Macro Refactor Plan

**Goal:** Reduce per-consumer compile cost by moving `defp` helpers OUT of `quote do` blocks. Keep inside the quote ONLY functions that users are intended to override via `defoverridable` **AND can actually plug into the DSL**.

**Scope:** Limited to `__using__` macros in `__extensions/mishka_gervaz/lib/`. Big template modules (`form/templates/standard.ex`, `table/templates/shared.ex`) are out of scope — they are not macros, so they pay no per-consumer cost.

**Workflow:** Run tests from `cd __extensions/mishka_gervaz && mix test` after each file. Then `mix compile --force` from `mishka_cms/` root to verify integration. Do NOT compile gervaz standalone.

---

## Tier 0 — DSL Reachability Audit (DO THIS FIRST)

`defoverridable` is meaningless if the DSL has no option to plug in the user's custom module. A function "overridable in theory" but not reachable from user code is dead weight — it pays compile cost without giving users any actual override surface.

For each `__using__` macro before refactoring, fill in this table (one row per macro file):

| Macro file | `.Default` module | Where the Default is referenced from | DSL option to swap it? | Verdict |
|---|---|---|---|---|
| `form/web/state/field_builder.ex` | `FieldBuilder.Default` | _(grep)_ | _(check `form/dsl.ex` + transformers)_ | reachable / dead / partial |
| `form/web/state/presentation.ex` | `Presentation.Default` | | DSL has `presentation do template ... end` — partial (template swappable, presentation module probably not) | |
| `form/web/state/access.ex` | `Access.Default` | | | |
| `form/web/state/group_builder.ex` | `GroupBuilder.Default` | | | |
| `form/web/state/step_builder.ex` | `StepBuilder.Default` | | | |
| `form/web/events.ex` | `Events.Default` | | | |
| `form/web/events/sanitization_handler.ex` | `.Default` | | | |
| `form/web/events/validation_handler.ex` | `.Default` | | | |
| `form/web/events/submit_handler.ex` | `.Default` | | | |
| `form/web/events/step_handler.ex` | `.Default` | | | |
| `form/web/events/upload_handler.ex` | `.Default` | | | |
| `form/web/events/relation_handler.ex` | `.Default` | | | |
| `form/web/events/hook_runner.ex` | `.Default` | | | |
| `form/web/data_loader.ex` | `.Default` | | | |
| `form/web/data_loader/record_loader.ex` | `.Default` | | | |
| `form/web/data_loader/relation_loader.ex` | `.Default` | | | |
| `form/web/data_loader/tenant_resolver.ex` | `.Default` | | | |
| `form/web/data_loader/hook_runner.ex` | `.Default` | | | |
| `table/...` mirror entries | | | | |

**How to fill each row:**
1. `cd __extensions/mishka_gervaz && grep -rn "<MacroModule>.Default" lib/ test/` — see who calls the Default.
2. Read those callers — is the module hard-coded, or pulled from config/DSL?
3. Check the DSL definition (e.g. `form/dsl.ex`, `table/dsl.ex`) for an option that lets users specify their own module (look for `:module` schema entries, `:atom` types pointing at modules).
4. Verdict per row:
   - **reachable** — DSL has an option, user can plug their module in. Refactor as planned: keep overridable surface, move defp helpers out.
   - **dead** — no DSL option exists. Two follow-ups (decide per row, see "Outcome decisions" below).
   - **partial** — some functions are reachable, others not.

**Outcome decisions for "dead" rows:**

- **(D1) Add a DSL option** so the override actually works. Adds a checkbox to that row's TODO. Use this when overridability is genuinely valuable for the user (e.g. swap the whole `Events` module).
- **(D2) Drop the `defoverridable`** and treat the macro as internal. The `__using__` becomes minimal (just `@behaviour` and any required imports), and we move the body to a plain module called directly. Use this when no one would realistically want to override (e.g. tiny accessors, internal builders).
- **(D3) Keep as-is, mark as deferred** — if it's unclear and the file is small, leave it for a later pass.

The choice between D1 and D2 changes the refactor scope for that file dramatically, so this audit MUST come before per-file refactoring.

**Output:** Append the filled-in table back into this plan file as a new section (or write to `MACROS_AUDIT.md` and link it). Each subsequent tier item must reference its audit row by name.

---

## Refactor Pattern (the recipe)

**Precondition:** Tier 0 audit row for this file is filled in. Don't refactor until you know whether the override surface is actually reachable from the DSL.

For each target file `lib/mishka_gervaz/<path>/foo.ex`:

1. Read the `quote do ... end` body inside `defmacro __using__`.
2. For each function inside the quote, classify:
   - **(A) Keep in quote** — appears in `defoverridable` AND the audit row says "reachable" (i.e. DSL has an option to plug a custom module in). OR is a `@impl` callback the user is expected to swap and reachable.
   - **(B) Move out** — `defp`, OR `def` that is not in `defoverridable`, OR `def` whose audit row says "dead" and outcome is **D2** (drop overridability). These cost per-consumer compile time for no benefit.
   - **(C) Discuss** — `defp X_handler, do: SomeModule.Default` accessors that look like override hooks but aren't currently overridable. Flag with comment `TODO(macro-refactor): promote to def + defoverridable + add DSL option?` and move on — do NOT change behavior in this pass.
3. Create a sibling `MishkaGervaz.<...>.Foo.Internal` module (file: `foo/internal.ex`) and move all (B) functions there as **public** `def`s.
4. Inside the quote, replace each call site with `Internal.fn_name(args)` (passing `__MODULE__` if the helper needs the consumer module — most don't).
5. Verify nothing in `Internal` references the consumer module's compile-time context (assigns from `Phoenix.Component.assigns_to_attributes`, captured `@behaviour`, etc.). If it does, that function must stay in the quote.
6. Run gervaz tests, then `mix compile --force` from parent root.

**HEEx caveat:** Some `defp render_*` functions use `~H` and may rely on the macro context. Test render output before/after — don't move any function with `~H` until the simpler ones are green.

**Non-goal:** No new abstractions, no API changes, no renaming. This is a mechanical extraction.

---

## Override Mechanism Reference (so the plan reads cold)

- Pattern: `defmodule MyApp.X do; use MishkaGervaz.X; def some_fn(...), do: ...; end`
- Compile-time, no `Application.get_env` lookup.
- `defoverridable` lists the public surface users may replace. They can call `super(...)` to compose.
- Sibling `.Default` module (e.g. `FieldBuilder.Default`) is the no-customization implementation, used when the consumer doesn't need a custom subclass.

---

## Phase A — Form/Table Parity Wiring (COMPLETED — May 2026)

Wired the form-side override surfaces to match the table-side DSL→runtime lookup pattern. Without this, `defoverridable` on form macros was a paper tiger because the form DSL never plugged user modules in. After Phase A every form override surface is reachable from the DSL exactly as on the table.

- [x] **A.1 — `Info.Form` accessors** (`lib/mishka_gervaz/_resource/info/form.ex`)
  Added `events/1`, `state/1`, `data_loader/1` mirroring `info/table.ex:631-675`. Imported `map_put_if_set` from `MishkaGervaz.Helpers`.
- [x] **A.2 — `BuildRuntimeConfig` transformer** (`lib/mishka_gervaz/form/transformers/build_runtime_config.ex`)
  Fixed pre-existing nil-leak bug in `build_events/1` (broke `||` fallback). Added `build_state/1` (Section-based via `get_opt`) and `build_data_loader/1` (Entity-based via `find_entity`). Wired into the persisted config map at lines 41-58. Aliased `Form.Entities.DataLoader`.
- [x] **A.3 — Form event sub-handlers** (`lib/mishka_gervaz/form/web/events.ex:78-120`)
  Replaced 7 zero-arity `defp xxx_handler` accessors with `defp xxx_handler(state)` that resolves via `Info.Form.events(state.static.resource)[:key] || XxxHandler.Default`. Mirror of `table/web/events.ex:99-130`. Updated all internal call sites; `sanitize_params/2` → `sanitize_params/3` (now takes state).
- [x] **A.4 — Form state sub-builders + module override** (`lib/mishka_gervaz/form/web/state.ex:437-499`)
  `init/3` now reads `Info.Form.state(resource)` and dispatches to `state[:module].init(...)` if set, else falls through to `do_init/4`. `do_init/3` signature changed to `do_init/4` taking `dsl_state`; each `*_builder()` accessor is now `Map.get(dsl_state, :field, field_builder())`. Mirror of `table/web/state.ex:548-574`.
- [x] **A.5 — Form data_loader sub-builders** (`lib/mishka_gervaz/form/web/data_loader.ex`)
  Added 4 `resolve_*(resource)` helpers: `resolve_record_loader/1`, `resolve_tenant_resolver/1`, `resolve_relation_loader/1`, `resolve_hook_runner/1`. Each `Map.get(Info.data_loader(resource), :key, default())` style. Updated all call sites in `load_record/3`, `new_record/2`, `load_relation_options/3`, `search_relation_options/4`, `load_readonly_relation_options/2`. Mirror of `table/web/data_loader.ex:408-454`.
- [x] **A.6 — Comprehensive override fixtures + tests** (`test/`)
  Real Spark fixtures for all surfaces (no `FakeResource`-style bypass — converted that to a real Spark module too):
  - `test/support/resources/form_state_dsl/` — 8 resources + 6 custom builders.
  - `test/support/resources/form_events_dsl/` — 10 resources + 8 custom handlers.
  - `test/support/resources/form_data_loader_dsl/` — 7 resources + 5 custom modules.
  - `test/mishka_gervaz/form/dsl/state_dsl_test.exs` — 21 tests (Info reads + per-builder runtime override + all-builders + whole-module + default).
  - `test/mishka_gervaz/form/dsl/events_dsl_test.exs` — 12 tests (per-handler Info reads + all-handlers + whole-module + nil-stripping).
  - `test/mishka_gervaz/form/dsl/data_loader_dsl_test.exs` — 9 tests (per-sub-builder Info reads + whole-module + nil-stripping).
- [x] **A.7 — Re-audit reachability** — All 18 previously broken/partial form surfaces flipped to **reachable**. Form/table parity for top-level `module:` defdelegate pattern preserved (both go through `__MODULE__.Default`; the `module:` DSL option is documented but framework dispatch still uses `Default` — same on both sides).

**Test totals after Phase A:** 2877/2877 gervaz tests pass (added 42 new). Parent `mishka_cms` compiles clean.

---

## Tier 1 — Heavyweight (>15 defp inside quote)

Highest compile-time payoff. Do these first.

- [x] **`lib/mishka_gervaz/form/web/events.ex`** — 67 defp, 1 def (`handle/3`) — DONE (May 2026)
  - All 67 `defp` (handler accessors + `do_handle/4` clauses + utility helpers) moved to outer level as `def` with `@doc false`. Macro body now just `handle/3` delegating to `MishkaGervaz.Form.Web.Events.do_handle/4`. `defoverridable handle: 3` retained.

- [x] **`lib/mishka_gervaz/table/web/events.ex`** — 70 defp, 1 def — DONE (May 2026)
  - All 70 `defp` moved to outer level. Macro body just `handle/3` delegating to `Events.do_handle/4`. Same pattern as form events.

- [x] **`lib/mishka_gervaz/table/web/data_loader/relation_loader.ex`** — 36 defp, 7 def — DONE (May 2026)
  - All 36 `defp` moved to outer level as public `def` with `@doc false`. The 9 overridable `def`s (`load_options/2,3`, `search_options/3,4`, `load_more_options/2,3`, `resolve_selected/3`, `load_with_selected/3,4`) stay in the quote and `import` the outer helpers via `import RelationLoader, only: [...]`.

- [x] **`lib/mishka_gervaz/form/web/data_loader/relation_loader.ex`** — 32 defp, 5 def — DONE (May 2026)
  - All 32 `defp` moved to outer level. The 5 overridables (`load_options/2,3`, `search_options/3,4`, `resolve_selected/3`) stay in the quote and import the outer helpers.

- [x] **`lib/mishka_gervaz/form/web/events/relation_handler.ex`** — 25 defp, 1 def — DONE (May 2026)
  - All 25 `defp` moved to outer level. Macro body now just `handle/4` delegating to `RelationHandler.do_handle/4`.

- [x] **`lib/mishka_gervaz/table/web/events/relation_filter_handler.ex`** — 24 defp, 1 def — DONE (May 2026)
  - All 24 `defp` moved to outer level. Macro body now just `handle/4` delegating to `RelationFilterHandler.do_handle/4`.

- [x] **`lib/mishka_gervaz/table/web/events/bulk_action_handler.ex`** — 21 defp, 13 def — DONE (May 2026)
  - 10 outer-level helpers extracted (`put_error_flash/2`, `hook_runner_for/1`, `run_lifecycle_hook/4`, `apply_lifecycle_socket/5`, `adapt_lifecycle_args/4`, `builtin_enabled?/2`, `resolve_action_spec/2`, `get_action_type/2`, `soft_delete_action?/3`, `execute_bulk_by_type/3`). `run_ash_bulk_action/5` stays in quote because it calls overridable `build_bulk_query/3`.

- [x] **`lib/mishka_gervaz/table/web/state/url_sync.ex`** — 18 defp, 4 def — DONE (May 2026)
  - 8 outer-level helpers extracted (`apply_url_filters/2`, `apply_url_sort/2`, `apply_url_page/2`, `apply_url_search/2`, `apply_url_path/2`, `apply_url_path_params/2`, `apply_url_preserved_params/2`, `apply_url_page_size/2`). `validate_url_filters/2` kept as `defp` at outer level (only used by `apply_url_filters`).

- [x] **`lib/mishka_gervaz/form/web/events/submit_handler.ex`** — 17 defp, 5 def — DONE (May 2026)
  - 8 outer-level helpers in same file (`format_form_errors/1`, `extract_form_level_errors/2`, `cleanup_temp_uploads/1`, `push_js_hook/4`, `merge_defaults/2`, `drop_protected_fields/2`, `field_restricted?/2`, `field_readonly?/2`). Uses `MishkaGervaz.Helpers.merge_relation_field_values/2` (multi-use). Kept in quote: `consume_upload_entries/4`, `merge_uploaded_files/4` — tightly bound to upload-flow.

---

## Tier 2 — Mid-weight (5–15 defp inside quote)

- [x] **`lib/mishka_gervaz/table/web/state/filter_builder.ex`** — 9 defp, 5 def — DONE (May 2026)
  - Moved to `MishkaGervaz.Helpers`: `get_resource_attributes/1` (already), `get_resource_calculations/1`, `get_resource_relationships/1`, `find_display_field/1`, `maybe_resolve_options/1`. Kept in quote: `maybe_resolve_type/2` (calls overridable `resolve_type/1`), `maybe_load_relationship_options/3` (calls overridable `load_relationship_options/2`).
- [x] **`lib/mishka_gervaz/form/web/data_loader/record_loader.ex`** — 5 defp, 3 def — DONE (May 2026)
  - Moved to `MishkaGervaz.Helpers`: `keyword_put_if_set/3` (replaces both `maybe_add_tenant/2` and `maybe_add_opt/3` — same shape), `resolve_tenant_from_record/2`.

---

## Tier 3 — Light (1–4 defp inside quote)

Small wins; do as a batch at the end.

- [x] **`lib/mishka_gervaz/ui_adapters/dynamic.ex`** — 3 defp, 1 def — DONE (May 2026)
  - `maybe_put/3` (in-quote AND module-level duplicate) → use existing `MishkaGervaz.Helpers.map_put_if_set/3` (same nil-skip semantics). `inject_config/1` kept in quote (uses module attributes `@site` etc.).
- [x] **`lib/mishka_gervaz/table/web/state/column_builder.ex`** — 3 defp, 4 def — DONE (May 2026)
  - `get_resource_attributes/1` → `MishkaGervaz.Helpers.get_resource_attributes/1`. `maybe_resolve_type/2` kept in quote (calls overridable `resolve_type/2`).
- [x] **`lib/mishka_gervaz/table/web/state/access.ex`** — 3 defp, 8 def — DONE (May 2026)
  - `get_tenant_field/1` and `default_record_visible?/2` → `MishkaGervaz.Helpers`.
- [x] **`lib/mishka_gervaz/table/web/data_loader/pagination_handler.ex`** — 3 defp, 7 def — DONE (May 2026)
  - `extract_results/1` (3 clauses) → `MishkaGervaz.Helpers.extract_results/1`.
- [x] **`lib/mishka_gervaz/form/web/events/step_handler.ex`** — 3 defp, 4 def — DONE (May 2026)
  - `find_next_step/2`, `find_prev_step/2`, `step_exists?/2` → `MishkaGervaz.Helpers`.
- [x] **`lib/mishka_gervaz/form/web/events/sanitization_handler.ex`** — 3 defp, 3 def — SKIPPED
  - Only candidate `sanitize_list_item/1` calls overridable `sanitize/1` and `sanitize_params/1` — must stay in quote (no safe extraction).
- [x] **`lib/mishka_gervaz/form/web/events/upload_handler.ex`** — 2 defp, 2 def — DONE (May 2026)
  - `resolve_upload_name/2` → `MishkaGervaz.Helpers.resolve_upload_name/2`.
- [x] **`lib/mishka_gervaz/form/web/state/field_builder.ex`** — 1 defp, 5 def — DONE (May 2026)
  - `get_resource_attributes/1` → `MishkaGervaz.Helpers.get_resource_attributes/1`.
- [x] **`lib/mishka_gervaz/form/web/events/validation_handler.ex`** — 1 defp, 4 def — DONE (May 2026)
  - `merge_relation_field_values/2` → `MishkaGervaz.Helpers.merge_relation_field_values/2`.

---

## Tier 4 — Skip (already optimal)

These have 0 `defp` inside their quote blocks, or the quote is trivially small. Do not touch.

- `lib/mishka_gervaz/behaviours/ui_adapter.ex` — generates only `defdelegate`/`def` shims, no defp.
- `lib/mishka_gervaz/form/behaviours/template.ex` — 4 thin delegating defs, all overridable.
- `lib/mishka_gervaz/table/behaviours/template.ex` — 4 thin delegating defs, all overridable.
- `lib/mishka_gervaz/form/web/state/builder.ex` — single `__builder_info__/1`.
- `lib/mishka_gervaz/table/web/state/builder.ex` — same.
- `lib/mishka_gervaz/form/web/events/builder.ex` — same.
- `lib/mishka_gervaz/form/web/state/presentation.ex` — 12 def (all overridable lookups), 0 defp.
- `lib/mishka_gervaz/table/web/state/presentation.ex` — 10 def, 0 defp.
- `lib/mishka_gervaz/form/web/state/group_builder.ex` — 0 defp.
- `lib/mishka_gervaz/form/web/state/step_builder.ex` — 0 defp.
- `lib/mishka_gervaz/form/web/state/access.ex` — 0 defp.
- `lib/mishka_gervaz/table/web/state/action_builder.ex` — 0 defp.
- `lib/mishka_gervaz/table/web/data_loader/{builder,filter_parser,hook_runner,query_builder,tenant_resolver}.ex` — 0 defp.
- `lib/mishka_gervaz/form/web/data_loader/{builder,hook_runner,tenant_resolver}.ex` — 0 defp.
- `lib/mishka_gervaz/{form,table}/web/events/hook_runner.ex` — 0 defp.
- `lib/mishka_gervaz/table/web/events/{record_handler,sanitization_handler,selection_handler}.ex` — 0 defp.
- `lib/mishka_gervaz/messages.ex` — verify (small file, likely fine).
- `lib/mishka_gervaz/table/behaviours/type_registry.ex` — verify.
- All sub-files under `data_loader/` not listed in Tier 1–3.

---

## Verification Protocol (per file)

1. `cd __extensions/mishka_gervaz && mix test` — full gervaz suite passes.
2. From `mishka_cms/` root: `mix compile --force` — no warnings introduced.
3. Grep the consumer modules (`*.Default` siblings, plus any user override examples in tests/fixtures) and confirm they still resolve all calls.
4. For files containing `~H` sigils inside the moved functions: render the relevant component in dev (form/table page) and visually verify.

After Tier 1 completes, optionally measure compile time on a clean build (`mix deps.compile mishka_gervaz` time) before/after to validate the win is real.

---

## Open Questions (resolve before starting Tier 1)

1. **DSL plug points for "dead" override surfaces** (from Tier 0 audit): for every row marked "dead" in the reachability table, decide D1 (add DSL option) vs D2 (drop overridability) vs D3 (defer). This is the biggest design decision of the refactor and must come first.
2. **Handler accessors (`defp sanitization_handler`, etc. in `form/web/events.ex` and `table/web/events.ex`):** Should these be promoted to `def` + `defoverridable` so users can swap one handler without rewriting the whole dispatcher? Current behavior: they are `defp` and the only override path is the entire `handle/3`. Tied to question 1 — if we add DSL options for individual handlers, promoting these makes sense.
3. **Internal module naming:** `Foo.Internal` vs `Foo.Helpers` vs `Foo.Impl`. Pick one and apply consistently. (Recommendation: `Internal` — matches Elixir community convention and signals "do not call from user code".)
4. **`@moduledoc false` on `Internal` modules:** Yes, hide from docs.

---

## Status

- [x] **Tier 0 audit complete** — Form had 1 reachable, 8 dead, 9 partial. Table had 21/21 reachable.
- [x] **Phase A — Form/Table parity wiring complete** (May 2026). All 18 form-side broken/partial surfaces flipped to **reachable** via runtime `Info.Form.{events,state,data_loader}/1` lookups. New tests: 33 (form/dsl/state, events, data_loader). Full suite 2877/2877 green.
- [x] Open questions resolved (handler accessors are now public outer-level defs callable as `Events.{sanitization,validation,...}_handler(state)`).
- [x] **Tier 1 complete (9/9 files)** — May 2026:
  - [x] `form/web/events/submit_handler.ex` (17 defp → 8 outer-level defs + uses existing `Helpers.merge_relation_field_values/2`)
  - [x] `table/web/state/url_sync.ex` (18 defp → 8 outer-level defs; `validate_url_filters/2` kept as defp at outer level)
  - [x] `table/web/events/bulk_action_handler.ex` (21 defp → 10 outer-level defs; `run_ash_bulk_action/5` stays in quote — calls overridable `build_bulk_query/3`)
  - [x] `table/web/events/relation_filter_handler.ex` (24 defp → all 24 moved to outer level; macro body now just `handle/4` delegating to `RelationFilterHandler.do_handle/4`)
  - [x] `form/web/events/relation_handler.ex` (25 defp → all 25 moved to outer level; macro body now just `handle/4` delegating to `RelationHandler.do_handle/4`)
  - [x] `form/web/data_loader/relation_loader.ex` (32 defp → all 32 moved to outer level; macro body keeps overridables and imports outer helpers)
  - [x] `table/web/data_loader/relation_loader.ex` (36 defp → all 36 moved to outer level; macro body keeps 9 overridables and imports outer helpers)
  - [x] `form/web/events.ex` (67 defp → all 67 moved to outer level; macro body now just `handle/3` delegating to `Events.do_handle/4`)
  - [x] `table/web/events.ex` (70 defp → all 70 moved to outer level; macro body now just `handle/3` delegating to `Events.do_handle/4`)
  - [ ] `table/web/events/bulk_action_handler.ex` (21 defp)
  - [ ] `table/web/events/relation_filter_handler.ex` (24 defp)
  - [ ] `form/web/events/relation_handler.ex` (25 defp)
  - [ ] `form/web/data_loader/relation_loader.ex` (32 defp)
  - [ ] `table/web/data_loader/relation_loader.ex` (36 defp)
  - [ ] `form/web/events.ex` (67 defp)
  - [ ] `table/web/events.ex` (70 defp)
- [x] **Tier 2 complete (2/2 files)** — May 2026.
- [x] **Tier 3 complete (10/10 files)** — May 2026. 9 extracted (1 candidate skipped: dispatches to overridable funcs). 7 helpers consolidated into `MishkaGervaz.Helpers` (no per-file `Internal` modules — see notes).
- [ ] Final compile-time measurement recorded.

## Phase B Implementation Notes (May 2026)

**Centralization rule (revised):** Only **multi-use** helpers go into `MishkaGervaz.Helpers`. A helper that is called from a single file lives at the **outer module level of that file** (above the `defmacro __using__`), not inside the quote and not in `Helpers`. This keeps Helpers meaningful (truly shared utilities) and avoids polluting it with single-use functions.

**Three placements for an extracted `defp`:**
1. **Inside the quote (don't extract)** — calls overridable functions, OR uses module attributes / consumer-module compile-time context.
2. **Outer module level of same file** (private helper for that macro only) — single-use, but must be moved out of the quote to avoid per-consumer compile cost. Imported back into the quote with `import ParentModule, only: [fn: arity]`.
3. **`MishkaGervaz.Helpers`** — used by 2+ files, or generic enough that future files would benefit (e.g. `map_put_if_set`).

**Recipe (per file):**
1. For each candidate `defp` inside the macro's `quote do`: classify.
   - **Move** — pure function, no calls to overridable functions inside the consumer module → add to `MishkaGervaz.Helpers` as a public `def`.
   - **Keep in quote** — calls overridable functions, OR uses module attributes / consumer-module compile-time context.
2. Add `import MishkaGervaz.Helpers, only: [fn: arity, ...]` inside the macro's `quote do` so call sites stay unchanged.
3. Delete the original `defp` from the quote.
4. Run `mix test` from `__extensions/mishka_gervaz`.

**Key constraint:** `defp` helpers that call overridable functions MUST stay in the quote. Examples:
- `column_builder.ex` `maybe_resolve_type/2` calls overridable `resolve_type/2` → kept.
- `sanitization_handler.ex` `sanitize_list_item/1` calls overridable `sanitize/1` and `sanitize_params/1` → kept (whole file skipped — only candidate had this issue).

**Helpers actually added to `MishkaGervaz.Helpers` (multi-use only):**
- `get_resource_attributes/1` — used by `field_builder`, `column_builder`, `filter_builder`.
- `merge_relation_field_values/2` — used by `validation_handler`, `submit_handler`.

**Single-use helpers placed at outer module level of their file** (NOT in Helpers):
- `submit_handler.ex` — `format_form_errors/1`, `extract_form_level_errors/2`, `cleanup_temp_uploads/1`, `push_js_hook/4`, `merge_defaults/2`, `drop_protected_fields/2`, `field_restricted?/2`, `field_readonly?/2`.
- `step_handler.ex` — `find_next_step/2`, `find_prev_step/2`, `step_exists?/2`.
- `upload_handler.ex` — `resolve_upload_name/2`.
- `record_loader.ex` — `keyword_put_if_set/3`, `resolve_tenant_from_record/2`.
- `pagination_handler.ex` — `extract_results/1`.
- `access.ex` (table state) — `get_tenant_field/1`, `default_record_visible?/2`.
- `filter_builder.ex` — `get_resource_calculations/1`, `get_resource_relationships/1`, `find_display_field/1`, `maybe_resolve_options/1`.
- `dynamic.ex` — uses existing `MishkaGervaz.Helpers.map_put_if_set/3` (the original `defp maybe_put` was duplicated; consolidated).

**Risk in Tier 1:** Files like `form/web/events.ex` have many interconnected `defp`s where extraction safety must be checked per-function. Recommend doing those one-by-one with full test runs between, not bulk-extracting.
