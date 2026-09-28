defmodule MishkaGervaz.Form.Entities.Access do
  @moduledoc """
  Per-mode (or global) access gate inside the `source` block.

  `access` declarations live alongside `actor_key` and `master_check`
  inside `MishkaGervaz.Form.Dsl.Source`. Each entry decides whether a
  given form mode (`:create` or `:update`) is reachable for the current
  user.

  Four calling styles are supported:

      # Style A — per-mode with keyword opts
      access :create, restricted: true

      # Style B — per-mode with condition function
      access :create, fn state -> state.master_user? end

      # Style C — global gate (`fn mode, state -> bool` in the mode slot)
      access fn mode, state -> mode == :update or state.master_user? end

      # Style D — per-mode, closed (or open) for everyone
      access :update, false

  Style C is the catch-all: it runs for every mode and is useful when
  you want one rule covering both `:create` and `:update`.

  Style D with `false` closes the mode: the form shows its denied state for it, and
  `MishkaGervaz.Form.Verifiers.ValidateSource` does not require the actions only that mode uses
  (`update` and `read` for `:update`, `create` for `:create`).

  See `MishkaGervaz.Form.Dsl.Source` for the surrounding section.
  """

  @type t :: %__MODULE__{
          mode: :create | :update | (atom(), map() -> boolean()),
          restricted: boolean(),
          condition: boolean() | (map() -> boolean()) | (atom(), map() -> boolean()) | nil,
          __identifier__: term(),
          __spark_metadata__: map() | nil
        }

  defstruct mode: nil,
            __identifier__: nil,
            restricted: false,
            condition: nil,
            __spark_metadata__: nil

  @opt_schema [
    mode: [
      type: {:or, [{:in, [:create, :update]}, {:fun, 2}]},
      doc: "Form mode (:create | :update) or global gate `fn mode, state -> boolean end`."
    ],
    restricted: [
      type: :boolean,
      default: false,
      doc: "Restrict this mode to master users."
    ],
    condition: [
      type: {:or, [:boolean, {:fun, 1}, {:fun, 2}]},
      doc:
        "Condition. `fn state -> boolean end`, `fn mode, state -> boolean end`, or a boolean — " <>
          "`false` closes the mode for everyone."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc false
  def transform(access), do: {:ok, access}
end
