<div align="center">

# MishkaGervaz

**A comprehensive, declarative UI library for the [Ash Framework](https://ash-hq.org/) — define admin tables, forms, and data-driven interfaces entirely through DSL.**

[![Hex.pm](https://img.shields.io/hexpm/v/mishka_gervaz.svg?style=flat-square)](https://hex.pm/packages/mishka_gervaz)
[![Hex Downloads](https://img.shields.io/hexpm/dt/mishka_gervaz.svg?style=flat-square)](https://hex.pm/packages/mishka_gervaz)
[![License](https://img.shields.io/hexpm/l/mishka_gervaz.svg?style=flat-square)](https://github.com/mishka-group/mishka_gervaz/blob/master/LICENSE)
[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-mishka--group-ea4aaa?style=flat-square&logo=github)](https://github.com/sponsors/mishka-group)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-mishkagroup-ffdd00?style=flat-square&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mishkagroup)

</div>

---

> [!WARNING]
> **Status — alpha.** APIs are still evolving and the library is not yet recommended for production.
> Track progress on [GitHub](https://github.com/mishka-group/mishka_gervaz) and the [CHANGELOG](https://github.com/mishka-group/mishka_gervaz/blob/master/CHANGELOG.md).

---

## Table of contents

- [Why MishkaGervaz?](#why-mishkagervaz)
- [Highlights](#highlights)
- [Installation](#installation)
- [Quick start](#quick-start)
  - [A table](#a-table)
  - [A form](#a-form)
- [Customization & overrides](#customization--overrides)
- [Architecture](#architecture)
- [Compatibility](#compatibility)
- [Documentation](#documentation)
- [Status & roadmap](#status--roadmap)
- [Contributing](#contributing)
- [Funding & sponsorship](#funding--sponsorship)
- [License](#license)

---

## Why MishkaGervaz?

Building admin UIs around an Ash resource is repetitive: list views, filters, sorting, pagination, edit forms, validation, multi-step wizards, file uploads, master / tenant access control. Each surface calls the same building blocks in slightly different ways.

**MishkaGervaz collapses that into a DSL.** Declare what your admin surface looks like — fields, columns, filters, steps, uploads, access rules — and the library builds the LiveView, wires events, runs queries, handles form state, and renders through a swappable UI adapter. Every component, behaviour, and adapter is overridable; nothing is hidden.

```elixir
mishka_gervaz do
  table do
    columns do
      column :title
      column :status, :select
      column :inserted_at, :datetime
    end

    filter :status, :select
    pagination type: :numbered, page_size: 20
  end

  form do
    fields do
      field :title, :text, required: true
      field :body, :textarea
      field :status, :select
    end
  end
end
```

That's the whole admin surface for a resource. Add a route, render the LiveComponent, and you have a working list page with create / edit forms, filters, sort, master / tenant access gates, and PubSub-powered real-time updates.

---

## Highlights

### Tables

- **Columns by atom or module** — built-ins for `:text`, `:number`, `:boolean`, `:date`, `:datetime`, `:enum`, `:tags`, `:money`, `:url`, `:image`, `:json`, `:uuid`, `:array`, plus a registry that accepts any custom column module.
- **Filters as first-class entities** — text, select, multi-select, date range, number range, boolean, relation (with search / load-more / static modes), with predicate operators (`contains`, `equals`, `gt`, `lt`, `between`, …).
- **Pagination** — numbered, load-more, infinite-scroll. Configurable page size, page-size options, max page size.
- **Sorting** — declarative, multi-column, deep-link-friendly.
- **URL sync** — page state (filters, sort, page, search) round-trips through the URL so refresh and copy-paste-link both work.
- **Real-time** — wire `pubsub` and rows update live without manual subscriptions.
- **Bulk actions** — `:type, :destroy, :archive` plus your own per-resource handlers.
- **Row actions** — custom buttons / links per row, with master / tenant gating.
- **Archive support** — soft-delete column, restore action, master-vs-tenant action mapping.
- **Auto-detect from Ash attributes** — `auto_columns true` builds a sensible default column set so you can opt in incrementally.

### Forms

- **Field types** — `:text`, `:textarea`, `:password`, `:select`, `:multi_select`, `:checkbox`, `:toggle`, `:date`, `:datetime`, `:range`, `:number`, `:hidden`, `:file`, `:upload`, `:relation`, `:json`, `:nested`, `:array_of_maps`, `:string_list`, `:combobox`, plus arbitrary custom modules.
- **Layout modes** — `:standard`, `:wizard` (sequential steps), `:tabs` (free navigation).
- **Groups** — visually section fields with optional collapsibles.
- **Validation** — driven by Ash actions; `phx-change` validation surfaces field-level errors automatically.
- **Lifecycle hooks** — `on_init`, `on_validate`, `before_save`, `after_save`, `on_cancel`, `on_change`, plus per-field JS hooks.
- **Notices** — info / warning / error / success banners with positions, group anchoring, step targeting, dismiss, and visibility predicates.
- **Header / footer chrome** — title, description, content, icon, class, and dynamic show/hide.
- **Uploads** — drop-zone or button styles; multi-file; auto-namespaced names so multiple form components on one page never collide; existing-files list + delete.
- **Relations** — static (load all), search (autocomplete), search-multi, load-more pagination; with `display_field`, `value_field`, `search_field`, `min_chars`, `debounce`, custom `load fn` for tenant filtering.
- **Constrained-map nested fields** — array-of-maps without changing your DB shape; add / remove rows; per-sub-field validation.
- **Per-mode access control** — `restricted: true` for master-only fields, function predicates for fine-grained gating, per-action `:create` / `:update` rules.
- **Master / tenant action tuples** — `read {:master_get, :read}` style; the same DSL drives different Ash actions depending on the user.

### Cross-cutting

- **UI adapter** — pluggable component layer. Tailwind adapter ships in; swap in your own to render against any design system.
- **Override surface** — every state builder, event handler, data loader, template, and adapter is `defoverridable`. Replace just one piece, all of them, or wire it via the DSL (`state do field MyMod end`).
- **i18n** — Gettext baked in; every label resolves through `Gettext` so translations land in the right places.
- **Fully tested core** — verifiers, transformers, sub-handlers, and helpers each have direct unit tests on top of integration tests; over **3,600** tests on the suite at the time of writing.

---

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:mishka_gervaz, "~> 0.0.1-alpha.1"},
    {:ash, "~> 3.0"},
    {:ash_phoenix, "~> 2.3"},
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

Fetch and compile:

```sh
mix deps.get
mix compile
```

Add the extension to your domain and resources:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [MishkaGervaz.Domain]

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end
      ui_adapter MishkaGervaz.UIAdapters.Tailwind

      actions do
        read {:master_read, :read}
        get {:master_get, :read}
        destroy {:master_destroy, :destroy}
      end
    end

    form do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end

      actions do
        create {:master_create, :create}
        update {:master_update, :update}
        read {:master_get, :read}
      end
    end
  end

  resources do
    resource MyApp.Blog.Post
  end
end

defmodule MyApp.Blog.Post do
  use Ash.Resource, extensions: [MishkaGervaz.Resource]
  # ... your resource
end
```

---

## Quick start

### A table

```elixir
mishka_gervaz do
  table do
    identity do
      name :blog_posts
      route "/admin/posts"
    end

    columns do
      column :title, :text, sortable: true
      column :status, :select, options: [:draft, :published, :archived]
      column :tags, :tags
      column :inserted_at, :datetime
    end

    filter :status, :select
    filter :title, :text

    pagination type: :numbered, page_size: 20
    realtime pubsub: MyApp.PubSub

    row_actions do
      action :edit, label: "Edit"
      action :destroy, label: "Delete", restricted: true
    end
  end
end
```

Mount it:

```heex
<.live_component
  module={MishkaGervaz.Table.Web.Live}
  id="posts-table"
  resource={MyApp.Blog.Post}
  current_user={@current_user}
/>
```

### A form

```elixir
mishka_gervaz do
  form do
    identity do
      name :blog_post_form
      route "/admin/posts"
    end

    fields do
      field :title, :text, required: true
      field :body, :textarea, required: true
      field :status, :select

      field :site_id, :relation do
        mode :search
        display_field :name
        restricted true
      end

      field :tags, :string_list
    end

    groups do
      group :content do
        label fn -> dgettext("blog", "Content") end
        fields [:title, :body]
      end

      group :metadata do
        fields [:status, :site_id, :tags]
      end
    end

    uploads do
      upload :cover do
        accept "image/*"
        max_file_size 5_000_000
      end
    end

    submit do
      create label: "Publish"
      update label: "Save changes"
      cancel label: "Cancel"
    end
  end
end
```

Mount it:

```heex
<.live_component
  module={MishkaGervaz.Form.Web.Live}
  id="post-form"
  resource={MyApp.Blog.Post}
  current_user={@current_user}
  record_id={@post_id}
/>
```

A wizard or tabbed multi-step form is a one-line change:

```elixir
layout do
  mode :wizard               # or :tabs

  step :basics do
    groups [:content]
  end

  step :metadata do
    groups [:metadata]
  end

  step :review do
    summary true
  end
end
```

---

## Customization & overrides

Three layers, each independent.

### 1. Per-callback override via `use`

```elixir
defmodule MyApp.Form.SubmitHandler do
  use MishkaGervaz.Form.Web.Events.SubmitHandler

  def transform_params(state, params) do
    params
    |> super(state)
    |> Map.put("ingested_at", DateTime.utc_now())
  end
end
```

`super` falls through to the default. Every callback in every sub-builder is `defoverridable`.

### 2. Wire your override via DSL

```elixir
mishka_gervaz do
  form do
    events do
      submit MyApp.Form.SubmitHandler
      validation MyApp.Form.ValidationHandler
    end

    state do
      field MyApp.Form.FieldBuilder
    end

    data_loader do
      relation MyApp.Form.RelationLoader
    end
  end
end
```

The DSL config is read at runtime by the orchestrator — no recompiling the macro tree.

### 3. Replace an entire subsystem module

```elixir
mishka_gervaz do
  form do
    events MyApp.CustomFormEvents
    state module: MyApp.CustomState
  end
end
```

See the moduledocs of `MishkaGervaz.Form.Web.State`, `MishkaGervaz.Form.Web.Events`, `MishkaGervaz.Form.Web.DataLoader`, and the table-side counterparts for the full override surface.

---

## Architecture

```
                +----------------------------+
                | Phoenix.LiveComponent      |
                | (Form.Web.Live /           |
                |  Table.Web.Live)           |
                +--------------+-------------+
                               |
       +-----------+-----------+-----------+-----------+
       |           |           |           |           |
       v           v           v           v           v
   +-------+   +-------+   +-------+   +-------+   +-------+
   | State |   | Events|   |DataLdr|   |Render |   |Adapter|
   +-------+   +-------+   +-------+   +-------+   +-------+
       |           |           |           |           |
       v           v           v           v           v
   sub-builders  sub-handlers  sub-builders templates  components
   (5)           (7)           (4)          (Standard) (Tailwind / yours)
```

- **State** — single struct per LiveComponent, partitioned into `static` (config, never re-renders) and dynamic (form, errors, current_step, …). Sub-builders for fields, groups, steps, presentation, access — each `defoverridable`.
- **DataLoader** — async record loading, AshPhoenix.Form construction, relation option loading, hook execution. Sub-builders: `RecordLoader`, `RelationLoader`, `TenantResolver`, `HookRunner`.
- **Events** — dispatch table for every `phx-` event the component sees. Sub-handlers: sanitization, validation, submit, step navigation, uploads, relation search, hooks.
- **Renderer** — thin bridge between LiveComponent and Templates; passes the static / dynamic split through so LiveView's diffing engine can skip work.
- **UI adapter** — the leaf layer that turns "render a button / a select / a stepper" into actual markup. Swap to retheme without touching the rest.

---

## Compatibility

| Dependency           | Required version    |
|----------------------|---------------------|
| Elixir               | `~> 1.17`           |
| Ash                  | `~> 3.0`            |
| AshPhoenix           | `~> 2.3`            |
| Phoenix LiveView     | `~> 1.0` (optional) |
| Spark                | `~> 2.6`            |
| Gettext              | `~> 1.0`            |
| Jason                | `~> 1.0`            |

---

## Documentation

- **API docs** — [hexdocs.pm/mishka_gervaz](https://hexdocs.pm/mishka_gervaz) (published with each release).
- **Guides** — every public module ends its `@moduledoc` with a "See also" cross-link to its siblings, so navigation through the codebase stays close to the runtime call graph.
- **Reference resources** — the test fixtures under `test/support/resources/` show every DSL feature in working form.

---

## Status & roadmap

| Area                            | Status        |
|---------------------------------|---------------|
| Table DSL + LiveView            | Alpha — feature-complete; API may change |
| Form DSL + LiveView             | Alpha — feature-complete; API may change |
| Tailwind UI adapter             | Alpha         |
| Multi-tenancy & access gates    | Stable in scope |
| Test coverage                   | 3,600+ tests, growing |
| GuardedStruct integration       | Planned for the field-types layer |
| Docs site                       | Planned       |

Breaking changes will be flagged in the [CHANGELOG](https://github.com/mishka-group/mishka_gervaz/blob/master/CHANGELOG.md).

---

## Contributing

Issues, PRs, and design discussions are welcome.

```sh
git clone https://github.com/mishka-group/mishka_gervaz.git
cd mishka_gervaz
mix deps.get
mix test
```

Before opening a PR:

- `mix test` — full suite green
- `mix format` — formatter passes
- `mix dialyzer` — type analysis clean (where applicable)

For larger feature work, please open an issue first so we can align on the design.

---

## Funding & sponsorship

MishkaGervaz is open-source software developed by [Mishka Group](https://github.com/mishka-group). If your team or company benefits from this work, please consider supporting continued development:

<div align="center">

[![GitHub Sponsors](https://img.shields.io/badge/GitHub_Sponsors-mishka--group-ea4aaa?style=for-the-badge&logo=github&logoColor=white)](https://github.com/sponsors/mishka-group)
&nbsp;&nbsp;&nbsp;
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-mishkagroup-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mishkagroup)

**Donate / sponsor:**
[github.com/sponsors/mishka-group](https://github.com/sponsors/mishka-group) · [buymeacoffee.com/mishkagroup](https://www.buymeacoffee.com/mishkagroup)

</div>

Sponsorship directly funds maintenance, new features, and documentation. Thank you.

---

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).

Copyright © Mishka Group and contributors.
