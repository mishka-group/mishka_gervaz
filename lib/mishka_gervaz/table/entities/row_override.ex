defmodule MishkaGervaz.Table.Entities.RowOverride do
  @moduledoc """
  Entity struct for row override configuration.

  Allows custom rendering of entire rows with different HTML/components.
  """

  @type t :: %__MODULE__{
          component: module() | nil,
          render: (map(), map(), [map()] -> Phoenix.LiveView.Rendered.t()) | nil,
          condition: (map() -> boolean()) | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :component,
    :render,
    :condition,
    __spark_metadata__: nil
  ]

  @opt_schema [
    component: [
      type: :atom,
      doc: "Custom LiveComponent module for row rendering."
    ],
    render: [
      type: {:fun, 3},
      doc: "Custom render function `fn assigns, record, columns -> HEEx`."
    ],
    condition: [
      type: {:fun, 1},
      doc: "Condition function `fn record -> boolean`. Override only applied when true."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the row override after DSL compilation.
  """
  def transform(%__MODULE__{} = override) do
    {:ok, override}
  end

  def transform(override), do: {:ok, override}
end
