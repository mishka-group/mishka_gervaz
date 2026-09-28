# Table → `source`

Which Ash actions the table runs, what it preloads, and whether archive is on.

```elixir
source do
  actor_key :current_user                       # assigns key holding the actor; default :current_user
  master_check fn user -> is_nil(user.site_id) end

  actions do
    read    {:master_read, :read}               # REQUIRED — resource or domain
    get     {:master_get, :read}                # required once rows are interactive
    destroy {:master_destroy, :destroy}         # required once a :destroy action exists
  end

  preload do
    always [:site, :tag_count]
    master master_media_category: :media_category
    tenant [:media_category]
  end

  archive do
    enabled true
    restricted false                            # true ⇒ only masters see the archive toggle
    visible fn state -> … end
    read_action    {:master_archived, :archived}
    get_action     {:master_get_archived, :get_archived}
    restore_action {:master_unarchive, :unarchive}
    destroy_action {:master_permanent_destroy, :permanent_destroy}
  end
end
```

## `actions`

Each value is an atom (same action for both roles) or `{master_action, tenant_action}`, chosen at
runtime by `master_check`.

Every action named — both elements of a tuple, on the resource or inherited from the domain — must
be an action of the resource of the matching kind: `read` and `get` read actions, `destroy` a destroy
action (checked only when a `:destroy` row or bulk action uses it). When archive applies,
`read_action` and `get_action` must be read actions, `restore_action` an update action and
`destroy_action` a destroy action. This is **compile-checked**: compiling prints a
`Spark.Error.DslError` warning naming the resource, the action and where it was set. Build with
`mix compile --warnings-as-errors` to have it fail the build.

Which are required is derived from what the table does:

| Key | Required when |
|---|---|
| `read` | always |
| `get` | `row.selectable true`, any bulk action, or a row action of type `:destroy` `:update` `:unarchive` `:permanent_destroy` `:accordion` |
| `destroy` | a row action or bulk action of type `:destroy` |

Declare them on the domain and let every resource inherit; the resource wins per key.

## `preload`

Entries are atoms or `{source, alias}` tuples. The three tiers exist so master and tenant can
expose **different relationships under the same alias** — `preload_aliases` on the state maps them
back, so a column reads `record.media_category` either way.

The tenant field itself is auto-detected from Ash multitenancy — never declare it.

> A preloaded relationship's read action must not have `pagination required?: true`. Preloads pass
> no limit, so it raises `Ash.Error.Invalid.LimitRequired` at runtime. Use
> `pagination offset?: true, required?: false` on that action.

## `archive`

Requires `AshArchival.Resource` in the resource's extensions — and, symmetrically, a resource with
`AshArchival.Resource` must have an `archive` block on itself **or its domain**. Both directions
fail the build.

`enabled false` turns the archive UI off without deleting the block. `restricted true` hides the
archive toggle from tenant users.

## TODO
- [ ] `read` reachable from the resource or the domain
- [ ] `get` declared if any row is selectable, expandable or acts on a single record
- [ ] `destroy` declared if anything destroys
- [ ] Every relationship a column, filter or template reads appears in `preload`
- [ ] Preloaded read actions use `pagination required?: false`
- [ ] `archive` present exactly when `AshArchival.Resource` is
- [ ] `master_check` declared (the table side has **no** fallback — it stays `nil`)

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.source`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-source) · [`mishka_gervaz.table.source.actions`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-source-actions) · [`mishka_gervaz.table.source.preload`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-source-preload) · [`mishka_gervaz.table.source.archive`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-source-archive)

- Domain — [`mishka_gervaz.table.actions`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-actions) · [`mishka_gervaz.table.archive`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-domain.html#mishka_gervaz-table-archive)

**Schema:** `MishkaGervaz.Table.Dsl.Source` · **Verifier:** `Table.Verifiers.ValidateSource`
