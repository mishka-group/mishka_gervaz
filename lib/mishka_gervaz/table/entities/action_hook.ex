defmodule MishkaGervaz.Table.Entities.ActionHook do
  @moduledoc """
  Entity struct for per-action lifecycle hooks (row + bulk).

  Stores a hook function attached to one or more action names.

  Used by entries like `before_row_action`, `after_row_action`,
  `on_row_action_success`, `on_row_action_error`, and the bulk variants.
  """

  @type t :: %__MODULE__{
          phase: atom(),
          names: atom() | [atom()],
          run: fun(),
          __spark_metadata__: map() | nil
        }

  defstruct [
    :phase,
    :names,
    :run,
    :__identifier__,
    :__spark_metadata__
  ]

  @opt_schema [
    names: [
      type: {:or, [:atom, {:list, :atom}]},
      required: true,
      doc: "Action name (atom) or list of action names this hook applies to."
    ],
    run: [
      type: {:or, [{:fun, 2}, {:fun, 3}]},
      required: true,
      doc: "Hook function to invoke."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(%__MODULE__{} = hook), do: {:ok, hook}
end
