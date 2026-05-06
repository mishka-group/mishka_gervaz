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

## Tier 1 — Heavyweight (>15 defp inside quote)

Highest compile-time payoff. Do these first.

- [ ] **`lib/mishka_gervaz/form/web/events.ex`** — 67 defp, 1 def (`handle/3`)
  - Only `handle/3` is in `defoverridable` (line 886).
  - All 67 `defp` are dispatcher internals (`do_handle/4` clauses, `sanitize_params/2`, `strip_empty_list_values/1`, etc.).
  - 7 handler accessors (`defp sanitization_handler`, `validation_handler`, `submit_handler`, `step_handler`, `upload_handler`, `relation_handler`, `hook_runner`) are **(C) Discuss** — currently not overridable; flag with TODO comment, leave as-is for now.
  - Action: extract all `do_handle/4` clauses + helpers to `MishkaGervaz.Form.Web.Events.Internal`. Public `handle/3` stays in quote and calls `Internal.do_handle(event, params, state, socket, __MODULE__)`.
  - Risk: `do_handle` may reference handler accessors; pass them in or have `Internal` look up via `consumer_module.__some_accessor__()`. Prefer keeping accessors in quote and passing the consumer module to `Internal`.

- [ ] **`lib/mishka_gervaz/table/web/events.ex`** — 70 defp, 1 def
  - Mirror of form/web/events.ex. Same approach.

- [ ] **`lib/mishka_gervaz/table/web/data_loader/relation_loader.ex`** — 36 defp, 7 def
  - Check which of the 7 `def` are in `defoverridable`. Keep those in quote.
  - Remaining `def` not in `defoverridable` are also (B) — move out.
  - Move all 36 `defp` to `RelationLoader.Internal`.

- [ ] **`lib/mishka_gervaz/form/web/data_loader/relation_loader.ex`** — 32 defp, 5 def
  - Same approach.

- [ ] **`lib/mishka_gervaz/form/web/events/relation_handler.ex`** — 25 defp, 1 def
  - One public `def` (likely the entry point in `defoverridable`). All 25 `defp` move to `RelationHandler.Internal`.

- [ ] **`lib/mishka_gervaz/table/web/events/relation_filter_handler.ex`** — 24 defp, 1 def
  - Mirror of above.

- [ ] **`lib/mishka_gervaz/table/web/events/bulk_action_handler.ex`** — 21 defp, 13 def
  - Audit each `def`: is it in `defoverridable`? If not and it's purely internal, move it.

- [ ] **`lib/mishka_gervaz/table/web/state/url_sync.ex`** — 18 defp, 4 def
  - Likely 4 `def` are public encode/decode entry points. Move 18 `defp` to `UrlSync.Internal`.

- [ ] **`lib/mishka_gervaz/form/web/events/submit_handler.ex`** — 17 defp, 5 def
  - Audit each `def` for overridability.

---

## Tier 2 — Mid-weight (5–15 defp inside quote)

- [ ] **`lib/mishka_gervaz/table/web/state/filter_builder.ex`** — 9 defp, 5 def
- [ ] **`lib/mishka_gervaz/form/web/data_loader/record_loader.ex`** — 5 defp, 3 def

---

## Tier 3 — Light (1–4 defp inside quote)

Small wins; do as a batch at the end.

- [ ] **`lib/mishka_gervaz/ui_adapters/dynamic.ex`** — 3 defp, 1 def
- [ ] **`lib/mishka_gervaz/table/web/state/column_builder.ex`** — 3 defp, 4 def
  - Already audited. Move `defp maybe_resolve_type/2` and `defp get_resource_attributes/1` to `ColumnBuilder.Internal`. (Third defp is one of the multi-clause forms — confirm count.)
- [ ] **`lib/mishka_gervaz/table/web/state/access.ex`** — 3 defp, 8 def
- [ ] **`lib/mishka_gervaz/table/web/data_loader/pagination_handler.ex`** — 3 defp, 7 def
- [ ] **`lib/mishka_gervaz/form/web/events/step_handler.ex`** — 3 defp, 4 def
- [ ] **`lib/mishka_gervaz/form/web/events/sanitization_handler.ex`** — 3 defp, 3 def
- [ ] **`lib/mishka_gervaz/form/web/events/upload_handler.ex`** — 2 defp, 2 def
- [ ] **`lib/mishka_gervaz/form/web/state/field_builder.ex`** — 1 defp, 5 def
  - Already audited. Move `defp get_resource_attributes/1` to `FieldBuilder.Internal`.
- [ ] **`lib/mishka_gervaz/form/web/events/validation_handler.ex`** — 1 defp, 4 def

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
- [ ] Open questions resolved (#2 handler accessor promotion answered: form events handlers ARE now accessor-style but still defp; promote in Phase B if desired).
- [ ] Tier 1 complete (9 files).
- [ ] Tier 2 complete (2 files).
- [ ] Tier 3 partial (3/10 files — pattern proven; remainder pending):
  - [x] `form/web/state/field_builder.ex` → `FieldBuilder.Internal.get_resource_attributes/1`
  - [x] `table/web/state/column_builder.ex` → `ColumnBuilder.Internal.get_resource_attributes/1`
  - [x] `form/web/events/validation_handler.ex` → `ValidationHandler.Internal.merge_relation_field_values/2`
- [ ] Final compile-time measurement recorded.

## Phase B Implementation Notes (May 2026)

**Pattern proven on 3 Tier 3 files.** The recipe:
1. Define `Foo.Internal` module ABOVE `Foo` in the same file with `@moduledoc false`.
2. Move pure `defp` helpers (no overridable-function calls, no consumer-module context) to `Internal` as public `def`s.
3. Add `alias Foo.Internal` inside the macro's `quote do`.
4. Replace internal call sites with `Internal.fn_name(...)`.

**Key constraint discovered:** `defp` helpers that call overridable functions (e.g. `column_builder.ex`'s `maybe_resolve_type/2` calls the overridable `resolve_type/2`) MUST stay in the quote — moving them to Internal would lose the overridable dispatch (Internal would call `Internal.resolve_type` which doesn't exist).

**Risk in Tier 1:** Files like `form/web/events.ex` have many interconnected `defp`s where extraction safety must be checked per-function. Recommend doing those one-by-one with full test runs between, not bulk-extracting.
