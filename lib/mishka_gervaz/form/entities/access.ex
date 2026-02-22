defmodule MishkaGervaz.Form.Entities.Access do
  @moduledoc """
  Entity struct for per-mode access control in form source configuration.

  Defines access rules for specific form modes (create/update), allowing
  restriction to master users or custom condition functions.
  """

  @type t :: %__MODULE__{
          mode: :create | :update,
          restricted: boolean(),
          condition: (map() -> boolean()) | nil,
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
      type: {:in, [:create, :update]},
      required: true,
      doc: "Form mode to control."
    ],
    restricted: [
      type: :boolean,
      default: false,
      doc: "Restrict this mode to master users."
    ],
    condition: [
      type: {:fun, 1},
      doc: "Custom condition. `fn state -> boolean end`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(access), do: {:ok, access}
end
