defmodule MishkaGervaz.Table.Entities.EmptyStateAction do
  @moduledoc """
  Entity struct for empty state call-to-action.
  """

  @type t :: %__MODULE__{
          label: String.t(),
          path: String.t(),
          icon: String.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :label,
    :path,
    icon: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    label: [
      type: :string,
      required: true,
      doc: "Button label."
    ],
    path: [
      type: :string,
      required: true,
      doc: "Path (supports {route} interpolation)."
    ],
    icon: [
      type: :string,
      doc: "Icon identifier."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(action), do: {:ok, action}
end
