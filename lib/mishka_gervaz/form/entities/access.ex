defmodule MishkaGervaz.Form.Entities.Access do
  @moduledoc """
  Per-mode (or global) access gate inside the `source` block.

  `access` declarations live alongside `actor_key` and `master_check`
  inside `MishkaGervaz.Form.Dsl.Source`. Each entry decides whether a
  given form mode (`:create` or `:update`) is reachable for the current
  user.

  Three calling styles are supported:

      # Style A — per-mode with keyword opts
      access :create, restricted: true

      # Style B — per-mode with condition function
      access :create, fn state -> state.master_user? end

      # Style C — global gate (`fn mode, state -> bool` in the mode slot)
      access fn mode, state -> mode == :update or state.master_user? end

  Style C is the catch-all: it runs for every mode and is useful when
  you want one rule covering both `:create` and `:update`.

  See `MishkaGervaz.Form.Dsl.Source` for the surrounding section.
  """

  @type t :: %__MODULE__{
          mode: :create | :update | (atom(), map() -> boolean()),
          restricted: boolean(),
          condition: (map() -> boolean()) | (atom(), map() -> boolean()) | nil,
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
      type: {:or, [{:fun, 1}, {:fun, 2}]},
      doc: "Condition function. `fn state -> boolean end` or `fn mode, state -> boolean end`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(access), do: {:ok, access}
end
