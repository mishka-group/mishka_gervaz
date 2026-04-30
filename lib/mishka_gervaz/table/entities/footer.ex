defmodule MishkaGervaz.Table.Entities.Footer do
  @moduledoc """
  Entity struct for table footer configuration.

  The footer renders below the pagination row. Mirrors
  `MishkaGervaz.Form.Entities.Footer` for cross-DSL consistency.

  ## Example

      layout do
        footer do
          content "Sorted by priority by default."
          class "mt-2 text-xs text-gray-400"
          visible true
          restricted false
        end
      end
  """

  @type t :: %__MODULE__{
          content: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          class: String.t() | nil,
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          render:
            (map() -> Phoenix.LiveView.Rendered.t())
            | (map(), map() -> Phoenix.LiveView.Rendered.t())
            | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct content: nil,
            class: nil,
            visible: true,
            restricted: false,
            render: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    content: [
      type: {:or, [:string, {:fun, 0}, {:fun, 1}]},
      doc: "Footer content. String, `fn -> _ end`, or `fn state -> _ end`."
    ],
    class: [
      type: :string,
      doc: "CSS classes for the footer wrapper."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Static or dynamic visibility. `fn state -> boolean() end`."
    ],
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Restrict to master users. `true` or `fn state -> boolean() end`."
    ],
    render: [
      type: {:or, [{:fun, 1}, {:fun, 2}]},
      doc:
        "Custom HEEx render. `fn assigns -> ~H\"...\" end` or `fn assigns, state -> ~H\"...\" end`."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional template-specific options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(footer), do: {:ok, footer}
end
