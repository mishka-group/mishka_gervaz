<div align="center">

# 🪄 MishkaGervaz

**A comprehensive, declarative UI library for the [Ash Framework](https://ash-hq.org/) — define admin tables, forms, and data-driven interfaces entirely through DSL.** ✨

[![Hex.pm](https://img.shields.io/hexpm/v/mishka_gervaz.svg?style=flat-square)](https://hex.pm/packages/mishka_gervaz)
[![Hex Downloads](https://img.shields.io/hexpm/dt/mishka_gervaz.svg?style=flat-square)](https://hex.pm/packages/mishka_gervaz)
[![License](https://img.shields.io/hexpm/l/mishka_gervaz.svg?style=flat-square)](https://github.com/mishka-group/mishka_gervaz/blob/master/LICENSE)
[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-mishka--group-ea4aaa?style=flat-square&logo=github)](https://github.com/sponsors/mishka-group)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-mishkagroup-ffdd00?style=flat-square&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mishkagroup)

</div>

---

> [!WARNING]
> **🚧 Status — alpha.** APIs are still evolving and the library is not yet recommended for production.
> Track progress on [GitHub](https://github.com/mishka-group/mishka_gervaz) and the [CHANGELOG](https://github.com/mishka-group/mishka_gervaz/blob/master/CHANGELOG.md).

---

## 📖 Table of contents

- [Why MishkaGervaz?](#-why-mishkagervaz)
- [Highlights](#-highlights)
- [Installation](#-installation)
- [Quick start](#-quick-start)
  - [A table](#-a-table)
  - [A form](#-a-form)
- [Customization & overrides](#-customization--overrides)
- [Architecture](#-architecture)
- [Compatibility](#-compatibility)
- [Documentation](#-documentation)
- [Status & roadmap](#-status--roadmap)
- [Contributing](#-contributing)
- [Funding & sponsorship](#-funding--sponsorship)
- [License](#-license)

---

## 💭 Why MishkaGervaz?

Building admin UIs around an Ash resource is repetitive: list views, filters, sorting, pagination, edit forms, validation, multi-step wizards, file uploads, master / tenant access control. Each surface calls the same building blocks in slightly different ways.

**MishkaGervaz collapses that into a DSL.** Declare what your admin surface looks like — fields, columns, filters, steps, uploads, access rules — and the library builds the LiveView, wires events, runs queries, handles form state, and renders through a swappable UI adapter. Every component, behaviour, and adapter is overridable; nothing is hidden.

```elixir
mishka_gervaz do
  table do
    identity do
      name :posts
      route "/admin/dashboard/blog/posts"
    end

    columns do
      column :title do
        sortable true
        label fn -> dgettext("blog", "Title") end
      end

      column :status do
        label fn -> dgettext("blog", "Status") end
      end
    end

    filters do
      filter :search, :text, fields: [:title, :slug]
      filter :status, :select do
        options [{"Published", :published}, {"Draft", :draft}]
      end
    end
  end

  form do
    fields do
      field :title do
        required true
        ui do
          label fn -> dgettext("blog", "Title") end
        end
      end

      field :status do
        options [{"Draft", :draft}, {"Published", :published}]
      end
    end
  end
end
```

That's the whole admin surface for a resource. Add a route, render the LiveComponent, and you have a working list page with create / edit forms, filters, sort, master / tenant access gates, and PubSub-powered real-time updates. 🚀

---

## ✨ Highlights

### 📊 Tables

- 🎨 **Columns by atom or module** — built-ins for `:text`, `:number`, `:boolean`, `:date`, `:datetime`, `:enum`, `:tags`, `:money`, `:url`, `:image`, `:json`, `:uuid`, `:array`, plus a registry that accepts any custom column module.
- 🔍 **Filters as first-class entities** — text, select, multi-select, date range, number range, boolean, relation (with search / load-more / static modes), with predicate operators (`contains`, `equals`, `gt`, `lt`, `between`, …).
- 📑 **Pagination** — numbered, load-more, infinite-scroll. Configurable page size, page-size options, max page size.
- ↕️ **Sorting** — declarative, multi-column, deep-link-friendly.
- 🔗 **URL sync** — page state (filters, sort, page, search) round-trips through the URL so refresh and copy-paste-link both work.
- ⚡ **Real-time** — wire `pubsub` and rows update live without manual subscriptions.
- 📦 **Bulk actions** — `:destroy`, `:unarchive`, `:permanent_destroy`, plus your own per-resource handlers.
- 🎯 **Row actions** — custom buttons / links per row, with master / tenant gating.
- 🗄️ **Archive support** — soft-delete column, restore action, master-vs-tenant action mapping.
- ✨ **Auto-detect from Ash attributes** — `auto_columns true` builds a sensible default column set so you can opt in incrementally.

### 📝 Forms

- 🧩 **Field types** — `:text`, `:textarea`, `:password`, `:select`, `:multi_select`, `:checkbox`, `:toggle`, `:date`, `:datetime`, `:range`, `:number`, `:hidden`, `:file`, `:upload`, `:relation`, `:json`, `:nested`, `:array_of_maps`, `:string_list`, `:combobox`, plus arbitrary custom modules.
- 🪜 **Layout modes** — `:standard`, `:wizard` (sequential steps), `:tabs` (free navigation).
- 📂 **Groups** — visually section fields with optional collapsibles.
- ✅ **Validation** — driven by Ash actions; `phx-change` validation surfaces field-level errors automatically.
- 🪝 **Lifecycle hooks** — `on_init`, `on_validate`, `before_save`, `after_save`, `on_cancel`, `on_change`, plus per-field JS hooks.
- 💬 **Notices** — info / warning / error / success banners with positions, group anchoring, step targeting, dismiss, and visibility predicates.
- 🎩 **Header / footer chrome** — title, description, content, icon, class, and dynamic show/hide.
- 📎 **Uploads** — drop-zone or button styles; multi-file; auto-namespaced names so multiple form components on one page never collide; existing-files list + delete.
- 🔗 **Relations** — static (load all), search (autocomplete), search-multi, load-more pagination; with `display_field`, `value_field`, `search_field`, `min_chars`, `debounce`, custom `load fn` for tenant filtering.
- 🪺 **Constrained-map nested fields** — array-of-maps without changing your DB shape; add / remove rows; per-sub-field validation.
- 🔐 **Per-mode access control** — `restricted: true` for master-only fields, function predicates for fine-grained gating, per-action `:create` / `:update` rules.
- 👥 **Master / tenant action tuples** — `read {:master_get, :read}` style; the same DSL drives different Ash actions depending on the user.

### 🌍 Cross-cutting

- 🎨 **UI adapter** — pluggable component layer. Tailwind adapter ships in; swap in your own to render against any design system.
- 🔧 **Override surface** — every state builder, event handler, data loader, template, and adapter is `defoverridable`. Replace just one piece, all of them, or wire it via the DSL (`state do field MyMod end`).
- 🌐 **i18n** — Gettext baked in; every label resolves through `Gettext` so translations land in the right places.
- 🧪 **Fully tested core** — verifiers, transformers, sub-handlers, and helpers each have direct unit tests on top of integration tests; over **3,600** tests on the suite at the time of writing.

---

## 🚀 Installation

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

Add the extension to your domain — set defaults that every resource in the domain inherits:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain]

  mishka_gervaz do
    table do
      actor_key :current_user
      ui_adapter MishkaGervaz.UIAdapters.Tailwind

      pagination do
        type :numbered
        page_size 20
        page_size_options [20, 50, 100]
      end

      realtime do
        pubsub MyApp.PubSub
      end

      actions do
        read {:master_read, :read}
        get {:master_get, :read}
        destroy {:master_destroy, :destroy}
      end

      archive do
        read_action {:master_archived, :archived}
        get_action {:master_get_archived, :get_archived}
        restore_action {:master_unarchive, :unarchive}
        destroy_action {:master_permanent_destroy, :permanent_destroy}
      end
    end

    form do
      actions do
        create {:master_create, :create}
        update {:master_update, :update}
        read {:master_get, :read}
      end

      submit do
        create label: fn -> dgettext("blog", "Create") end
        update label: fn -> dgettext("blog", "Save Changes") end
        cancel label: fn -> dgettext("blog", "Cancel") end
        position :bottom
      end
    end
  end

  resources do
    resource MyApp.Blog.Post
  end
end
```

Then add the resource extension:

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    extensions: [MishkaGervaz.Resource]

  # ... your attributes / actions / relationships
end
```

---

## 🎯 Quick start

### 📊 A table

```elixir
mishka_gervaz do
  table do
    identity do
      name :posts
      route "/admin/dashboard/blog/posts"
    end

    source do
      preload do
        always [:site, :tag_count, :comment_count]
      end
    end

    columns do
      column :title do
        sortable true

        render fn value ->
          assigns = %{title: value}
          ~H"<span class=\"font-semibold\">{@title}</span>"
        end
      end

      column :site_id do
        static true
        requires [:site_id, :site]
        label fn -> dgettext("blog", "Site") end
      end

      column :status do
        sortable true
        sort_field [:status]
      end

      column :inserted_at do
        sortable true
      end
    end

    filters do
      filter :search, :text, fields: [:title, :slug, :excerpt]

      filter :site_id, :relation do
        mode :search_multi
        display_field :name
        search_field :name
        restricted true
      end

      filter :status, :select do
        options [
          {"Published", :published},
          {"Draft", :draft},
          {"Archived", :archived}
        ]
      end
    end

    row_actions do
      action :edit do
        type :edit
        visible :active

        ui do
          icon "hero-pencil-square"
          class "text-blue-600 hover:bg-blue-50"
        end
      end

      action :archive do
        type :destroy
        confirm "Archive this post?"
        visible :active
      end

      action :unarchive do
        type :unarchive
        confirm "Restore this post?"
        visible :archived
      end
    end

    bulk_actions do
      action :archive, type: :destroy, confirm: "Archive selected posts?"

      action :unarchive,
        type: :unarchive,
        confirm: "Restore selected posts?",
        visible: :archived
    end

    url_sync do
      mode :bidirectional
      params [:filters, :sort, :page, :search]
      prefix "posts"
    end
  end
end
```

🎬 Mount it:

```heex
<.live_component
  module={MishkaGervaz.Table.Web.Live}
  id="posts-table"
  resource={MyApp.Blog.Post}
  current_user={@current_user}
/>
```

### 📝 A form

```elixir
mishka_gervaz do
  form do
    identity do
      name :post_form
    end

    source do
      preload do
        master [:master_collections, :master_tags]
        tenant [:tenant_collections, :tenant_tags]
      end
    end

    fields do
      field :title do
        required true

        ui do
          label fn -> dgettext("blog", "Title") end
          placeholder "Post title"
        end
      end

      field :status do
        options [
          {"Draft", :draft},
          {"Published", :published},
          {"Scheduled", :scheduled}
        ]
      end

      field :language, :combobox do
        options fn ->
          MyApp.Repo.distinct_languages()
          |> Enum.map(fn lang -> {String.upcase(lang), lang} end)
        end

        ui do
          label fn -> dgettext("blog", "Language") end
          placeholder "en, fa, ar, ..."
        end
      end

      field :site_id, :relation do
        mode :search
        display_field :name
        search_field :name
        restricted true
        show_on :create

        ui do
          label fn -> dgettext("blog", "Site") end
        end
      end

      field :tag_ids, :relation do
        virtual true
        resource MyApp.Blog.Tag
        mode :search_multi
        display_field :name
        search_field :name
        depends_on :site_id

        load fn query, state ->
          site_id =
            if state.master_user?,
              do: Map.get(state.field_values, :site_id),
              else: state.current_user.site_id

          Ash.Query.filter_input(query, %{site_id: site_id})
        end
      end

      field :body, :textarea do
        required true

        ui do
          label fn -> dgettext("blog", "Body") end
        end
      end
    end

    groups do
      group :basic_info do
        fields [:title, :status, :language]

        ui do
          label fn -> dgettext("blog", "Basics") end
        end
      end

      group :relationships do
        fields [:site_id, :tag_ids]

        ui do
          label fn -> dgettext("blog", "Relationships") end
        end
      end

      group :content do
        fields [:body]

        ui do
          label fn -> dgettext("blog", "Content") end
        end
      end
    end

    uploads do
      upload :cover do
        accept "image/*"
        max_file_size 5_000_000
      end
    end
  end
end
```

🎬 Mount it:

```heex
<.live_component
  module={MishkaGervaz.Form.Web.Live}
  id="post-form"
  resource={MyApp.Blog.Post}
  current_user={@current_user}
  record_id={@post_id}
/>
```

🪜 A wizard or tabbed multi-step form is a one-block change:

```elixir
layout do
  mode :wizard            # or :tabs

  step :basics do
    groups [:basic_info]
  end

  step :metadata do
    groups [:relationships]
  end

  step :content do
    groups [:content]
  end

  step :review do
    summary true
  end
end
```

---

## 🔧 Customization & overrides

Three layers, each independent.

### 1️⃣ Per-callback override via `use`

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

### 2️⃣ Wire your override via DSL

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

### 3️⃣ Replace an entire subsystem module

```elixir
mishka_gervaz do
  form do
    events MyApp.CustomFormEvents
    state module: MyApp.CustomState
  end
end
```

📚 See the moduledocs of `MishkaGervaz.Form.Web.State`, `MishkaGervaz.Form.Web.Events`, `MishkaGervaz.Form.Web.DataLoader`, and the table-side counterparts for the full override surface.

---

## 🏗️ Architecture

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

- 🧠 **State** — single struct per LiveComponent, partitioned into `static` (config, never re-renders) and dynamic (form, errors, current_step, …). Sub-builders for fields, groups, steps, presentation, access — each `defoverridable`.
- 🚚 **DataLoader** — async record loading, AshPhoenix.Form construction, relation option loading, hook execution. Sub-builders: `RecordLoader`, `RelationLoader`, `TenantResolver`, `HookRunner`.
- 📡 **Events** — dispatch table for every `phx-` event the component sees. Sub-handlers: sanitization, validation, submit, step navigation, uploads, relation search, hooks.
- 🎬 **Renderer** — thin bridge between LiveComponent and Templates; passes the static / dynamic split through so LiveView's diffing engine can skip work.
- 🎨 **UI adapter** — the leaf layer that turns "render a button / a select / a stepper" into actual markup. Swap to retheme without touching the rest.

---

## 🔌 Compatibility

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

## 📚 Documentation

- 📖 **API docs** — [hexdocs.pm/mishka_gervaz](https://hexdocs.pm/mishka_gervaz) (published with each release).
- 🧭 **Guides** — every public module ends its `@moduledoc` with a "See also" cross-link to its siblings, so navigation through the codebase stays close to the runtime call graph.
- 🔬 **Reference resources** — the test fixtures under `test/support/resources/` show every DSL feature in working form.

---

## 🛣️ Status & roadmap

| Area                            | Status        |
|---------------------------------|---------------|
| Table DSL + LiveView            | 🟡 Alpha — feature-complete; API may change |
| Form DSL + LiveView             | 🟡 Alpha — feature-complete; API may change |
| Tailwind UI adapter             | 🟡 Alpha       |
| Multi-tenancy & access gates    | 🟢 Stable in scope |
| Test coverage                   | 🟢 3,600+ tests, growing |
| GuardedStruct integration       | 🔵 Planned for the field-types layer |
| Docs site                       | 🔵 Planned     |

Breaking changes will be flagged in the [CHANGELOG](https://github.com/mishka-group/mishka_gervaz/blob/master/CHANGELOG.md).

---

## 🤝 Contributing

Issues, PRs, and design discussions are welcome.

```sh
git clone https://github.com/mishka-group/mishka_gervaz.git
cd mishka_gervaz
mix deps.get
mix test
```

Before opening a PR:

- ✅ `mix test` — full suite green
- ✅ `mix format` — formatter passes
- ✅ `mix dialyzer` — type analysis clean (where applicable)

For larger feature work, please open an issue first so we can align on the design. 💬

---

## 💖 Funding & sponsorship

MishkaGervaz is open-source software developed by [Mishka Group](https://github.com/mishka-group). If your team or company benefits from this work, please consider supporting continued development:

<div align="center">

[![GitHub Sponsors](https://img.shields.io/badge/GitHub_Sponsors-mishka--group-ea4aaa?style=for-the-badge&logo=github&logoColor=white)](https://github.com/sponsors/mishka-group)
&nbsp;&nbsp;&nbsp;
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-mishkagroup-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mishkagroup)

**☕ Donate / sponsor:**
[github.com/sponsors/mishka-group](https://github.com/sponsors/mishka-group) · [buymeacoffee.com/mishkagroup](https://www.buymeacoffee.com/mishkagroup)

</div>

Sponsorship directly funds maintenance, new features, and documentation. Thank you. 💚

---

## 📜 License

Apache License 2.0 — see [`LICENSE`](LICENSE).

Copyright © Mishka Group and contributors.
