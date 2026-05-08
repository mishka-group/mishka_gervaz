defmodule MishkaGervaz.Form.Entities.Schema do
  @moduledoc false

  # Shared schema fragments used by multiple form entities. Keeping them
  # here avoids drift across the 7 entities that gate themselves with
  # `visible` / `restricted` predicates (Field, Group, Header, Footer,
  # Notice, Submit.Button, Step). Merge into each entity's `@opt_schema`
  # with `++ MishkaGervaz.Form.Entities.Schema.access_predicates()` (or
  # the narrower accessors when only one of the two applies).

  @visible_key [
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Static or dynamic visibility. `fn state -> boolean() end`."
    ]
  ]

  @restricted_key [
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Restrict to master users. `true` or `fn state -> boolean() end`."
    ]
  ]

  @doc """
  The `:visible` schema entry — boolean or `fn state -> boolean() end`,
  default `true`.
  """
  @spec visible_key() :: keyword()
  def visible_key, do: @visible_key

  @doc """
  The `:restricted` schema entry — boolean or `fn state -> boolean() end`,
  default `false` (everyone sees it). Set to `true` or a predicate to
  gate to master users.
  """
  @spec restricted_key() :: keyword()
  def restricted_key, do: @restricted_key

  @doc """
  Both `:visible` and `:restricted` schema entries — the standard
  access-control pair used by most form chrome and fields.
  """
  @spec access_predicates() :: keyword()
  def access_predicates, do: @visible_key ++ @restricted_key
end
