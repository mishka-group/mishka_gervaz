# Table → `identity`

Names the table and gives it a base route. Required as soon as the table declares any column,
filter, row action or bulk action.

```elixir
identity do
  name :posts
  route "/admin/dashboard/blog/posts"
  stream_name :posts
end
```

| Option | Type | Note |
|---|---|---|
| `name` | atom | **required** — unique table id |
| `route` | string | **required** — base path used by links and row actions; may contain `:param` segments |
| `stream_name` | atom | defaults to a value derived from `name` |

## Path params filter the query

A route with params — `"/admin/dashboard/document/sections/:workspace_version_id"` — puts them on
`state.path_params`, and **any path param whose name matches a resource attribute becomes a
filter on the query**:

| value | filter |
|---|---|
| `nil` | `is_nil(attribute)` |
| a list, on a scalar attribute | `attribute in list` |
| anything else | `attribute == value` |

An array attribute is compared with `==` whatever the value is. A mount can pass a list itself —
`url_state={%{path_params: %{key: @keys}}}` shows only the rows whose `key` is one of `@keys`.

That is usually what you want. When it is not, name the param something that is not an attribute:

```elixir
# `editor_pick_node` is prefixed deliberately — it must filter nothing.
# `site_id` in the same map is left alone, because there the filter IS the point.
route "/admin/media/:site_id/:editor_pick_node"
```

Read them in predicates and hooks: `state.path_params[:workspace_version_id]`.

## TODO
- [ ] `name` unique across the app (it is the id you address `send_update/2` with)
- [ ] `route` matches a route in the router
- [ ] Every path param either intentionally filters, or is named so it cannot
- [ ] `stream_name` left derived unless two tables on one page collide

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.table.identity`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-table-identity)

**Schema:** `MishkaGervaz.Table.Dsl.Identity` · **Verifier:** `Table.Verifiers.ValidateIdentity`
